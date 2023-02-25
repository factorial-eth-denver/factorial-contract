// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/ITokenization.sol";
import "../interfaces/ITrigger.sol";
import "../interfaces/IWrapper.sol";

contract Tokenization is ITokenization, ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VariableCache {
        address caller;
        uint24 tokenType;
        uint24 slippage;
        uint256 initialValue;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    mapping(uint24 => address) private tokenTypeSpecs;
    mapping(uint256 => uint256) private wrappingRelationship;
    mapping(uint24 => address) public connectionPoolBitmap;
    mapping(uint24 => address) public connectionPoolBitmap;


    /// @dev Throws if called by not router.
    modifier onlySpec() {
        require(msg.sender == tokenTypeSpecs[cache.tokenType], 'Only spec');
        _;
    }

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() external initializer {
        __Ownable_init();
    }

    function registerTokenType(uint24 _tokenType, address _tokenTypeSpec) external onlyOwner {
        require(tokenTypeSpecs[_tokenType] == address(0), 'Already registered');
        tokenTypeSpecs[_tokenType] = _tokenTypeSpec;
    }

    /// External Functions
    function wrap(uint24 _wrapperType, bytes calldata _param) external override {
        IWrapper(tokenTypeSpecs[_wrapperType]).wrap(_param);
    }

    function unwrap(uint _tokenId, uint _amount) external override {
        uint24 tokenType = uint24(_tokenId >> 232);
        IWrapper(tokenTypeSpecs[tokenType]).unwrap(_tokenId, _amount);
    }

    function trigger(uint _tokenId, bytes calldata _param) external override{
        uint24 tokenType = uint24(_tokenId >> 232);
        ITrigger(tokenTypeSpecs[tokenType]).trigger(_tokenId, _param);
    }

    function getValue(uint _tokenId, uint _amount) external view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenTypeSpecs[tokenType]).getValue(_tokenId, _amount);
    }

    /// Callback Functions
    function doTransferIn(uint256 _tokenId, uint256 _amount) external override onlySpec {
        uint24 tokenType = uint24(_tokenId >> 232);
        if (tokenType == 0) {
            IERC20Upgradeable(address(uint160(_tokenId))).safeTransferFrom(cache.caller, address(this), _amount);
            _mint(msg.sender, _tokenId, _amount, "");
        } else {
            safeTransferFrom(cache.caller, msg.sender, _tokenId, _amount, '');
        }
    }

    function doTransferInBatch(uint256[] calldata _tokenIds, uint256[] calldata _amounts) external override onlySpec {
        require(_tokenIds.length == _amounts.length, 'Invalid param');
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint24 tokenType = uint24(_tokenIds[i] >> 232);
            if (tokenType == 0) {
                IERC20Upgradeable(address(uint160(_tokenIds[i]))).safeTransferFrom(cache.caller, address(this), _amounts[i]);
                _mint(msg.sender, _tokenIds[i], _amounts[i], "");
            } else {
                safeTransferFrom(cache.caller, msg.sender, _tokenIds[i], _amounts[i], '');
            }
        }
    }

    function doTransferOut(address recipient, uint256 _tokenId, uint256 _amount) external override onlySpec {
        uint24 tokenType = uint24(_tokenId >> 232);
        if (recipient == address(0)) recipient = cache.caller;
        if (tokenType == 0) {
            IERC20Upgradeable(address(uint160(_tokenId))).safeTransfer(recipient, _amount);
            _burn(msg.sender, _tokenId, _amount);
        } else {
            _safeTransferFrom(msg.sender, recipient, _tokenId, _amount, '');
        }
    }

    function doTransferOutBatch(address recipient, uint256[] calldata _tokenIds, uint256[] calldata _amounts) external override onlySpec {
        require(_tokenIds.length == _amounts.length, 'Invalid param');
        if (recipient == address(0)) recipient = cache.caller;
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint24 tokenType = uint24(_tokenIds[i] >> 232);
            if (tokenType == 0) {
                IERC20Upgradeable(address(uint160(_tokenIds[i]))).safeTransfer(recipient, _amounts[i]);
                _burn(msg.sender, _tokenIds[i], _amounts[i]);
            } else {
                _safeTransferFrom(msg.sender, recipient, _tokenIds[i], _amounts[i], '');
            }
        }
    }

    function mintCallback(uint256 _sequentialN, uint256 _amount) public override onlySpec returns (uint){
        uint256 tokenId = (uint256(cache.tokenType) << 232) + (_sequentialN << 160) + uint256(uint160(cache.caller));
        _mint(cache.caller, tokenId, _amount, "");
        return tokenId;
    }

    function burnCallback(uint256 _tokenId, uint256 _amount) public onlySpec {
        _burn(cache.caller, _tokenId, _amount);
    }

    /// View functions
    function caller() external override view returns (address) {
        return cache.caller;
    }

    function beforeWrap(uint _inputToken, uint _amount, uint24 _slippage) external {
        cache.caller = msg.sender;
        cache.tokenType = uint24(_inputToken >> 232);
        cache.slippage = _slippage;
        cache.initialValue += tokenization.getValue(_inputToken, _amount);
    }

    function afterWrap(uint _outPutToken, uint _amount) external {
        uint afterValue = tokenization.getValue(_inputToken, _amount);
        require(afterValue > cache.initialValue * (10000 - uint256(cache.slippage)));
        cache.caller = address(0);
        cache.tokenType = 0;
        cache.initialValue = 0;
    }
}
