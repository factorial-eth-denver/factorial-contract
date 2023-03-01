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

contract Tokenization is ITokenization, OwnableUpgradeable, UUPSUpgradeable, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct ValuationFactor {
        uint256 collateralFactor;
        uint256 debtFactor;
    }

    mapping(uint24 => address) private tokenTypeSpecs;
    mapping(uint256 => uint256) private wrappingRelationship;
    mapping(uint256 => ValuationFactor) private guideValuationFactors;
    mapping(address => mapping(uint256 => ValuationFactor)) private customValuationFactors;

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _asset) external initializer initContext(_asset) {
        __Ownable_init();
    }

    function registerTokenType(uint24 _tokenType, address _tokenTypeSpec) external onlyOwner {
        require(tokenTypeSpecs[_tokenType] == address(0), 'Already registered');
        tokenTypeSpecs[_tokenType] = _tokenTypeSpec;
    }

    function setGuideTokenFactor(uint256 _tokenTypeOrId, uint _collateralFactor, uint _debtFactor) external onlyOwner {
        guideValuationFactors[_tokenTypeOrId] = ValuationFactor(
            _collateralFactor,
            _debtFactor
        );
    }

    function setCustomTokenFactor(uint256 _tokenTypeOrId, uint _collateralFactor, uint _debtFactor) external {
        customValuationFactors[msg.sender][_tokenTypeOrId] = ValuationFactor(
            _collateralFactor,
            _debtFactor
        );
    }

    /// External Functions
    function wrap(uint24 _wrapperType, bytes calldata _param) external override returns (uint){
        return IWrapper(tokenTypeSpecs[_wrapperType]).wrap(msgSender(), _wrapperType, _param);
    }

    function unwrap(uint _tokenId, uint _amount) external override {
        uint24 tokenType = uint24(_tokenId >> 232);
        IWrapper(tokenTypeSpecs[tokenType]).unwrap(msgSender(), _tokenId, _amount);
    }

    function getValue(uint _tokenId, uint _amount) public view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenTypeSpecs[tokenType]).getValue(_tokenId, _amount);
    }

    function getValueAsCollateral(address lender, uint _tokenId, uint _amount) public view returns (uint) {
        uint256 tokenType = _tokenId >> 232;
        if (tokenType == 0) tokenType = _tokenId;
        uint256 customFactor = customValuationFactors[lender][tokenType].collateralFactor;
        uint256 guideFactor = guideValuationFactors[tokenType].collateralFactor;

        uint256 collateralFactor = customFactor > guideFactor ? guideFactor : customFactor;
        return IWrapper(tokenTypeSpecs[uint24(_tokenId >> 232)]).getValue(_tokenId, _amount) * collateralFactor / 10000;
    }

    function getValueAsDebt(address lender, uint _tokenId, uint _amount) public view returns (uint) {
        uint256 tokenType = _tokenId >> 232;
        if (tokenType == 0) tokenType = _tokenId;
        uint256 customFactor = customValuationFactors[lender][tokenType].debtFactor;
        uint256 guideFactor = guideValuationFactors[tokenType].debtFactor;

        uint256 borrowFactor = customFactor < guideFactor ? guideFactor : customFactor;
        return IWrapper(tokenTypeSpecs[uint24(_tokenId >> 232)]).getValue(_tokenId, _amount) * borrowFactor / 10000;
    }
}
