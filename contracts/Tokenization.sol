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
        uint256 maximumLoss;
        uint256 inputValue;
        uint256 outputValue;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    mapping(uint24 => address) private tokenTypeSpecs;
    mapping(uint256 => uint256) private wrappingRelationship;
    mapping(address => bool) public factorialModules;


    /// @dev Throws if called by not router.
    modifier onlySpec() {
        require(msg.sender == tokenTypeSpecs[cache.tokenType], 'Only spec');
        _;
    }

    /// @dev Throws if called by not router.
    modifier onlyFactorialModule() {
        require(factorialModules[msg.sender], 'Only factorial module');
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

    function getValue(uint _tokenId, uint _amount) public view override returns (uint) {
        uint24 tokenType = uint24(_tokenId >> 232);
        return IWrapper(tokenTypeSpecs[tokenType]).getValue(_tokenId, _amount);
    }

    function transferERC20(uint _tokenId, uint _amount, address _to) external onlyFactorialModule {
        require(_tokenId >> 160 == 0, 'Not ERC20');
        IERC20Upgradeable(address(uint160(_tokenId))).safeTransfer(_to, _amount);
    }

    function mintCallback(uint256 _sequentialN, uint256 _amount) public override onlySpec returns (uint){
        uint256 tokenId = (uint256(cache.tokenType) << 232) + (_sequentialN << 160) + uint256(uint160(cache.caller));
        _mint(cache.caller, tokenId, _amount, "");
        return tokenId;
    }

    function burnCallback(uint256 _tokenId, uint256 _amount) public onlySpec {
        _burn(cache.caller, _tokenId, _amount);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || from == cache.caller,
            "ERC1155: caller is not token owner or caller"
        );
        if (from == cache.caller) {
            cache.inputValue += getValue(id, amount);
        } else if (to == cache.caller) {
            cache.outputValue += getValue(id, amount);
        }
        if (from == cache.caller && (id >> 160) == 0) {
            IERC20Upgradeable(address(uint160(id))).safeTransferFrom(cache.caller, address(this), amount);
            _mint(to, id, amount, '');
        } else if (to == cache.caller && (id >> 160) == 0) {
            IERC20Upgradeable(address(uint160(id))).safeTransfer(cache.caller, amount);
            _burn(from, id, amount);
        } else {
            _safeTransferFrom(from, to, id, amount, data);
        }
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            from == _msgSender() || from == cache.caller,
            "ERC1155: caller is not token owner or caller"
        );
        uint256[] memory newIds;
        uint256[] memory newAmounts;
        for (uint idx = 0; idx < ids; idx++) {
            uint id = ids[idx];
            uint amount = amounts[idx];
            if (from == cache.caller) {
                cache.inputValue += getValue(id, amount);
            } else if (to == cache.caller) {
                cache.outputValue += getValue(id, amount);
            }
            if (from == cache.caller && (id >> 160) == 0) {
                IERC20Upgradeable(address(uint160(id))).safeTransferFrom(cache.caller, address(this), amount);
                _mint(to, id, amount, '');
            } else if (to == cache.caller && (id >> 160) == 0) {
                IERC20Upgradeable(address(uint160(id))).safeTransfer(cache.caller, amount);
                _burn(from, id, amount);
            } else {
                newIds.push(id);
                newAmounts.push(amount);
            }
        }
        _safeBatchTransferFrom(from, to, newIds, newAmounts, data);
    }
}
