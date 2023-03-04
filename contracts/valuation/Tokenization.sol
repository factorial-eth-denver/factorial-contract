// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/ITokenization.sol";
import "../../interfaces/ITrigger.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/IAsset.sol";
import "../utils/FactorialContext.sol";

/// @dev This contract enables valuation by tokenizing all asset through wrapping.
contract Tokenization is ITokenization, OwnableUpgradeable, UUPSUpgradeable, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct ValuationFactor {
        uint256 collateralFactor;
        uint256 debtFactor;
    }

    /// ----- SETTING STATES -----
    mapping(uint24 => address) private tokenWrapper;
    mapping(uint256 => uint256) private wrappingRelationship;
    mapping(uint256 => ValuationFactor) private guideValuationFactors;
    mapping(address => mapping(uint256 => ValuationFactor)) private customValuationFactors;

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @dev Initialize tokenization contract
    /// @param _asset The factorial asset management contract
    function initialize(address _asset) external initializer initContext(_asset) {
        __Ownable_init();
    }


    /// ----- SETTER FUNCTIONS -----
    /// @dev Register token type.
    /// @param _tokenType 24-bit token type id
    /// @param _tokenWrapper The address of token wrapping contract
    function registerTokenType(uint24 _tokenType, address _tokenWrapper) external onlyOwner {
        require(tokenWrapper[_tokenType] == address(0), 'Already registered');
        tokenWrapper[_tokenType] = _tokenWrapper;
    }

    /// @dev Set token collateral/debt guide factor.
    /// @param _tokenTypeOrId If erc20 asset, token id. If factorial asset, 24bit tokenType.
    /// @param _collateralFactor The collateral factor of token/wrapping sepc.
    /// @param _debtFactor The debt factor of token/wrapping spec.
    function setGuideTokenFactor(uint256 _tokenTypeOrId, uint256 _collateralFactor, uint256 _debtFactor) external onlyOwner {
        require(_collateralFactor < 10000 && _debtFactor > 10000);
        guideValuationFactors[_tokenTypeOrId] = ValuationFactor(
            _collateralFactor,
            _debtFactor
        );
    }

    /// @dev Set token collateral/debt custom factor.
    /// @param _tokenTypeOrId If erc20 asset, token id. If factorial asset, 24bit tokenType.
    /// @param _collateralFactor The collateral factor of token/wrapping sepc.
    /// @param _debtFactor The debt factor of token/wrapping spec.
    function setCustomTokenFactor(uint256 _tokenTypeOrId, uint256 _collateralFactor, uint256 _debtFactor) external {
        require(_collateralFactor < 10000 && _debtFactor > 10000);
        customValuationFactors[msg.sender][_tokenTypeOrId] = ValuationFactor(
            _collateralFactor,
            _debtFactor
        );
    }


    /// ----- EXTERNAL FUNCTIONS -----
    /// @dev Wrap token/assets to ERC1155 factorial token.
    /// @param _wrapperType The 24-bit wrapper type. Not underlying asset type.
    /// @param _param The parameter using specific wrapping contract.
    function wrap(uint24 _wrapperType, bytes calldata _param) external override returns (uint){
        return IWrapper(tokenWrapper[_wrapperType]).wrap(msgSender(), _wrapperType, _param);
    }

    /// @dev Unwrap token/assets from ERC1155 factorial token.
    /// @param _tokenId The ERC1155 factorial token id.
    /// @param _amount The amount of token to unwrap. If NFT token, it should be 1.
    function unwrap(uint256 _tokenId, uint256 _amount) external override {
        uint24 tokenType = uint24(_tokenId >> 232);
        IWrapper(tokenWrapper[tokenType]).unwrap(msgSender(), _tokenId, _amount);
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Return value of token by id and amount.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued. If NFT token, it should be 1.
    function getValue(uint256 _tokenId, uint256 _amount) external view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenWrapper[tokenType]).getValue(_tokenId, _amount);
    }

    /// @dev Return token value as collateral. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address. This is for custom factor.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued. If NFT token, it should be 1.
    function getValueAsCollateral(address _lendingProtocol, uint256 _tokenId, uint256 _amount) external view returns (uint) {
        uint256 tokenType = _tokenId >> 232;
        if (tokenType == 0) tokenType = _tokenId;
        uint256 customFactor = customValuationFactors[_lendingProtocol][tokenType].collateralFactor;
        uint256 collateralFactor = guideValuationFactors[tokenType].collateralFactor;
        if (customFactor != 0) collateralFactor = customFactor > collateralFactor ? collateralFactor : customFactor;
        return IWrapper(tokenWrapper[uint24(_tokenId >> 232)]).getValueAsCollateral(
            _lendingProtocol,
            _tokenId,
            _amount
        ) * collateralFactor / 10000;
    }

    /// @dev Return token value as debt. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address. This is for custom factor.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued. If NFT token, it should be 1.
    function getValueAsDebt(address _lendingProtocol, uint256 _tokenId, uint256 _amount) external view returns (uint) {
        uint256 tokenType = _tokenId >> 232;
        if (tokenType == 0) tokenType = _tokenId;
        uint256 customFactor = customValuationFactors[_lendingProtocol][tokenType].debtFactor;
        uint256 debtFactor = guideValuationFactors[tokenType].debtFactor;
        if (customFactor != 0) debtFactor = customFactor < debtFactor ? debtFactor : customFactor;
        return IWrapper(tokenWrapper[uint24(_tokenId >> 232)]).getValueAsDebt(
            _lendingProtocol,
            _tokenId,
            _amount
        ) * debtFactor / 10000;
    }
}
