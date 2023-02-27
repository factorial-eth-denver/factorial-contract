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

contract FactorialAsset is ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VariableCache {
        address caller;
        uint256 maximumLoss;
        uint256 inputValue;
        uint256 outputValue;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    ITokenization public tokenization;

    /// ----- VARIABLE STATES -----
    mapping(address => bool) public factorialModules;

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

    function registerFactorialModule(address _factorialModule) external onlyOwner {
        factorialModules[_factorialModule] = true;
    }

    function setTokenization(address _tokenization) external onlyOwner {
        tokenization = ITokenization(_tokenization);
    }

    function mint(address _to, uint _tokenId, uint _amount) public override onlyFactorialModule {
        _mint(_to, _tokenId, _amount, "");
    }

    function burn(address _from, uint _tokenId, uint _amount) public onlyFactorialModule {
        _burn(_from, _tokenId, _amount);
    }

    function beforeExecute(uint _maximumLoss) external onlyFactorialModule {
        require(cache.caller != address(0), 'Locked');
        cache.caller = msg.sender;
        cache.maximumLoss = _maximumLoss;
    }

    function afterExecute() external onlyFactorialModule {
        require(cache.outputValue + cache.maximumLoss > cache.inputValue, 'Over slippage');
        cache.caller = address(0);
        cache.maximumLoss = 0;
        cache.inputValue = 0;
        cache.outputValue = 0;
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
            factorialModules[_msgSender()] ||
            from == _msgSender() || from == cache.caller,
            "ERC1155: caller is not token owner or caller"
        );
        if (from == cache.caller) {
            cache.inputValue += tokenization.getValue(id, amount);
        } else if (to == cache.caller) {
            cache.outputValue += tokenization.getValue(id, amount);
        }
        if (id >> 160 == 0) {
            if (from == cache.caller || factorialModules[from]) {
                if (to == cache.caller || factorialModules[to]) {
                    IERC20Upgradeable(address(uint160(id))).safeTransferFrom(from, to, amount);
                } else {
                    IERC20Upgradeable(token).safeTransferFrom(from, address(this), amount);
                    _mint(to, id, _amount, "");
                }
                return;
            } else if (to == cache.caller || factorialModules[to]) {
                _burn(from, id, amount);
                IERC20Upgradeable(token).safeTransferFrom(address(this), to, amount);
                return;
            }
        }
        _safeTransferFrom(from, to, id, amount, data);
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
            factorialModules[_msgSender()] ||
            from == _msgSender() || from == cache.caller,
            "ERC1155: caller is not token owner or caller"
        );
        for (uint i = 0; i < ids.length; i++) {
            if (from == cache.caller) {
                cache.inputValue += tokenization.getValue(ids[i], amounts[i]);
            } else if (to == cache.caller) {
                cache.outputValue += tokenization.getValue(ids[i], amounts[i]);
            }
        }
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}
