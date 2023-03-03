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
import "../../../interfaces/ILending.sol";
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/ILiquidation.sol";
import "../../../interfaces/IAsset.sol";
import "../../utils/FactorialContext.sol";

import "../../connector/library/SafeCastUint256.sol";

import "hardhat/console.sol";

contract DebtNFT is OwnableUpgradeable, ERC1155HolderUpgradeable, IWrapper, FactorialContext {
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
    mapping(uint256 => DebtToken) public tokenInfos;
    ITokenization public tokenization;
    uint256 public sequentialN;

    /// @dev Throws if called by not valuation module.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _asset) public initializer initContext(_asset) {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
    }

    function wrap(
        address _caller,
        uint24 _tokenType,
        bytes memory _param
    ) external override onlyTokenization returns (uint) {
        (uint256 collateralToken, uint256 collateralAmount, address liquidationModule)
        = abi.decode(_param, (uint256, uint256, address));

        uint tokenId = (uint256(_tokenType) << 232) + (sequentialN++ << 160) + uint256(uint160(_caller));

        // Store states
        tokenInfos[tokenId] = DebtToken(
            collateralToken,
            collateralAmount,
            liquidationModule
        );

        // Mint token to user
        asset.safeTransferFrom(_caller, address(this), collateralToken, collateralAmount, '');
        asset.mint(_caller, tokenId, 1);
        return tokenId;
    }

    function unwrap(address _caller, uint _tokenId, uint _amount) external override onlyTokenization {
        DebtToken memory nft = tokenInfos[_tokenId];
        asset.burn(_caller, _tokenId, 1);
        asset.safeTransferFrom(address(this), _caller, nft.collateralToken, nft.collateralAmount, '');
        delete tokenInfos[_tokenId];
    }

    function getValue(uint _tokenId, uint) public view override returns (uint){
        DebtToken memory nft = tokenInfos[_tokenId];
        uint collateralValue = tokenization.getValue(nft.collateralToken, nft.collateralAmount);
        (uint debtTokenId, uint debtAmount) = ILending(address(uint160(_tokenId))).getDebt(_tokenId);
        uint debTokenValue = tokenization.getValue(debtTokenId, debtAmount);
        if (collateralValue < debTokenValue) {
            return 0;
        }
        return collateralValue - debTokenValue;
    }

    function getValueWithFactor(address _lendingProtocol, uint _tokenId, uint) public view returns (uint){
        DebtToken memory nft = tokenInfos[_tokenId];
        uint collateralValue = tokenization.getValueAsCollateral(
            _lendingProtocol,
            nft.collateralToken,
            nft.collateralAmount
        );
        (uint debtTokenId, uint debtAmount) = ILending(address(uint160(_tokenId))).getDebt(_tokenId);
        uint debtValue = tokenization.getValueAsDebt(
            _lendingProtocol,
            debtTokenId,
            debtAmount
        );
        if (collateralValue < (debtValue)) {
            return 0;
        }
        return collateralValue - debtValue;
    }

    function getValueAsCollateral(
        address,
        uint,
        uint
    ) public pure override returns (uint) {
        revert('Not supported');
    }

    function getValueAsDebt(
        address,
        uint,
        uint
    ) public pure override returns (uint) {
        revert('Not supported');
    }

    function getNextTokenId(address _caller, uint24 _tokenType) public view override returns (uint) {
        return (uint256(_tokenType) << 232) + (sequentialN << 160) + uint256(uint160(_caller));
    }
}
