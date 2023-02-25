// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../interfaces/ITokenization.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/ITrigger.sol";
import "../../interfaces/ITriggerAction.sol";
import "../../interfaces/IMortgage.sol";

contract TriggerNFT is ITrigger, IWrapper, OwnableUpgradeable, ERC1155HolderUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct TriggerNFT {
        uint256 initialValue;
        uint256 collateralToken;
        uint256 collateralAmount;
        uint256 stopLossThreshold;
        uint256 takeProfitThreshold;
        uint256 maturity;
        address triggerAction;
    }

    mapping(uint256 => TriggerNFT) private tokenInfos;
    ITokenization public tokenization;
    uint256 private sequentialN;

    /// @dev Throws if called by not tokenization module.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
    }

    struct WrapParam {
        uint256 collateralToken;
        uint256 collateralAmount;
        uint256 stopLossThreshold;
        uint256 takeProfitThreshold;
        uint256 maturity;
        address triggerAction;
    }

    function wrap(bytes calldata _param) external override onlyTokenization {
        WrapParam memory param = abi.decode(_param, (WrapParam));
        require(param.maturity == 0 || param.maturity > block.timestamp, 'Already over maturity');

        tokenization.doTransferIn(param.collateralToken, param.collateralAmount);

        uint tokenId = tokenization.mintCallback(sequentialN++, 1);
        tokenInfos[tokenId] = TriggerNFT(
            tokenization.getValue(param.collateralToken, param.collateralAmount),
            param.collateralToken,
            param.collateralAmount,
            param.stopLossThreshold,
            param.takeProfitThreshold,
            param.maturity,
            param.triggerAction
        );
    }

    function unwrap(uint _tokenId, uint _amount) public override onlyTokenization {
        TriggerNFT memory nft = tokenInfos[_tokenId];
        ITokenization(tokenization).burnCallback(_tokenId, 1);
        tokenization.doTransferOut(address(0), nft.collateralToken, nft.collateralAmount);
        delete tokenInfos[_tokenId];
    }

    enum TriggerType {STOP_LOSS, TAKE_PROFIT, MATURITY}

    struct TriggerParam {
        TriggerType triggerType;
    }

    function trigger(uint _tokenId, bytes calldata _param) external override onlyTokenization {
        TriggerParam memory param = abi.decode(_param, (TriggerParam));
        TriggerNFT memory nft = tokenInfos[_tokenId];
        if (param.triggerType == TriggerType.STOP_LOSS) {
            uint256 value = getValue(nft.collateralToken, nft.collateralAmount);
            require(nft.initialValue * nft.stopLossThreshold / 1e6 >= value, 'Not exceed threshold');
        } else if (param.triggerType == TriggerType.TAKE_PROFIT) {
            uint256 value = getValue(nft.collateralToken, nft.collateralAmount);
            require(nft.initialValue * nft.takeProfitThreshold / 1e6 <= value, 'Not exceed threshold');
        } else if (param.triggerType == TriggerType.MATURITY) {
            require(nft.maturity <= block.timestamp, 'Not yet');
        } else {
            revert();
        }
        ITokenization(tokenization).burnCallback(_tokenId, 1);
        tokenization.doTransferOut(nft.triggerAction, nft.collateralToken, nft.collateralAmount);
        ITriggerAction(nft.triggerAction).trigger(_tokenId, nft.collateralToken, nft.collateralAmount);
    }

    function getValue(uint _tokenId, uint _amount) public view override returns (uint){
        TriggerNFT memory token = tokenInfos[_tokenId];
        return tokenization.getValue(token.collateralToken, token.collateralAmount);
    }
}
