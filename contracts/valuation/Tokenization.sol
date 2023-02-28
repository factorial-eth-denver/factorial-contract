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

    mapping(uint24 => address) private tokenTypeSpecs;
    mapping(uint256 => uint256) private wrappingRelationship;

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _asset) external initializer initContext(_asset){
        __Ownable_init();
    }

    function registerTokenType(uint24 _tokenType, address _tokenTypeSpec) external onlyOwner {
        require(tokenTypeSpecs[_tokenType] == address(0), 'Already registered');
        tokenTypeSpecs[_tokenType] = _tokenTypeSpec;
    }

    /// External Functions
    function wrap(uint24 _wrapperType, bytes calldata _param) external override {
        IWrapper(tokenTypeSpecs[_wrapperType]).wrap(msgSender(), _wrapperType, _param);
    }

    function unwrap(uint _tokenId, uint _amount) external override {
        uint24 tokenType = uint24(_tokenId >> 232);
        IWrapper(tokenTypeSpecs[tokenType]).unwrap(msgSender(), _tokenId, _amount);
    }

    function getValue(uint _tokenId, uint _amount) public view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenTypeSpecs[tokenType]).getValue(_tokenId, _amount);
    }
}
