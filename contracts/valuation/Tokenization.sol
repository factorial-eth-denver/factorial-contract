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

    struct VariableCache {
        address wrapCaller;
        uint24 tokenType;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    mapping(uint24 => address) private tokenTypeSpecs;
    mapping(uint256 => uint256) private wrappingRelationship;

    /// @dev Throws if called by not router.
    modifier onlySpec() {
        require(msgSender() == tokenTypeSpecs[cache.tokenType], 'Only spec');
        _;
    }

    /// @dev Throws if called by not router.
    modifier writeCache(uint24 _wrapperType) {
        cache.wrapCaller = msgSender();
        cache.tokenType = _wrapperType;
        _;
        cache.wrapCaller = address(0);
        cache.tokenType = 0;
    }

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _asset) external initializer initContext(_asset){
        __Ownable_init();
    }

    function registerTokenType(uint24 _tokenType, address _tokenTypeSpec) external onlyOwner {
        require(tokenTypeSpecs[_tokenType] == address(0), 'Already registered');
        tokenTypeSpecs[_tokenType] = _tokenTypeSpec;
    }

    function caller() external view returns (address) {
        return cache.wrapCaller;
    }

    /// External Functions
    function wrap(uint24 _wrapperType, bytes calldata _param) external override writeCache(_wrapperType) {
        IWrapper(tokenTypeSpecs[_wrapperType]).wrap(_param);
    }

    function unwrap(uint _tokenId, uint _amount) external override writeCache(uint24(_tokenId >> 232)) {
        uint24 tokenType = cache.tokenType;
        IWrapper(tokenTypeSpecs[tokenType]).unwrap(_tokenId, _amount);
    }

    function getValue(uint _tokenId, uint _amount) public view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenTypeSpecs[tokenType]).getValue(_tokenId, _amount);
    }

    function mintCallback(uint256 _sequentialN, uint256 _amount) public override onlySpec returns (uint){
        uint256 tokenId = (uint256(cache.tokenType) << 232) + (_sequentialN << 160) + uint256(uint160(cache.wrapCaller));
        asset.mint(cache.wrapCaller, tokenId, _amount);
        return tokenId;
    }

    function burnCallback(uint256 _tokenId, uint256 _amount) public onlySpec {
        asset.burn(cache.wrapCaller, _tokenId, _amount);
    }
}
