// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/IMortgage.sol";
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/ILiquidation.sol";
import "../../../interfaces/IAsset.sol";

contract DebtNFT is OwnableUpgradeable, ERC1155HolderUpgradeable, IWrapper {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct DebtToken {
        uint256 collateralToken;
        uint256 collateralAmount;
        address liquidationModule;
    }

    struct TokenFactors {
        uint16 borrowFactor; // The borrow factor for this token, multiplied by 1e4.
        uint16 collateralFactor; // The collateral factor for this token, multiplied by 1e4.
    }

    mapping(address => TokenFactors) public tokenFactors; // Mapping from token address to oracle info.
    mapping(uint256 => DebtToken) private tokenInfos;
    ITokenization public tokenization;
    IAsset public asset;
    uint256 private sequentialN;

    /// @dev Throws if called by not valuation module.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _asset) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        asset = IAsset(_asset);
    }

    function wrap(bytes memory _param) external override onlyTokenization {
        (uint256 collateralToken, uint256 collateralAmount, address liquidationModule)
        = abi.decode(_param, (uint256, uint256, address));

        asset.safeTransferFrom(
            tokenization.caller(),
            address(this),
            collateralToken,
            collateralAmount,
            ''
        );

        uint tokenId = tokenization.mintCallback(sequentialN++, 1);
        tokenInfos[tokenId] = DebtToken(
            collateralToken,
            collateralAmount,
            liquidationModule
        );
    }

    function unwrap(uint _tokenId, uint _amount) external override onlyTokenization {
        DebtToken memory nft = tokenInfos[_tokenId];
        ITokenization(tokenization).burnCallback(_tokenId, 1);
        IMortgage(address(uint160(_tokenId))).repay(_tokenId);
        asset.safeTransferFrom(address(this), msg.sender, nft.collateralToken, _amount, '');
        delete tokenInfos[_tokenId];
    }

    function getValue(uint _tokenId, uint) public view override returns (uint){
        DebtToken memory nft = tokenInfos[_tokenId];
        uint collateralValue = tokenization.getValue(nft.collateralToken, nft.collateralAmount);
        (uint debtTokenType, uint debtAmount) = IMortgage(address(uint160(_tokenId))).getDebt(_tokenId);
        if (collateralValue < (debtTokenType * debtAmount)) {
            return 0;
        }
        return collateralValue - (debtTokenType * debtAmount);
    }
}