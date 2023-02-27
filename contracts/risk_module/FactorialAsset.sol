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
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public override {
        require(
            factorialModules[_msgSender()] ||
            _from == _msgSender() || _from == cache.caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );
        if (_from == cache.caller) {
            cache.inputValue += tokenization.getValue(_id, _amount);
        } else if (_to == cache.caller) {
            cache.outputValue += tokenization.getValue(_id, _amount);
        }
        if (_id >> 160 == 0) {
            address erc20Token = address(uint160(_id));
            if (_from == cache.caller || factorialModules[_from]) {
                if (_to == cache.caller || factorialModules[_to]) {
                    IERC20Upgradeable(erc20Token).safeTransferFrom(_from, _to, _amount);
                } else {
                    IERC20Upgradeable(erc20Token).safeTransferFrom(_from, address(this), _amount);
                    _mint(_to, _id, _amount, "");
                }
                return;
            } else if (_to == cache.caller || factorialModules[_to]) {
                _burn(_from, _id, _amount);
                IERC20Upgradeable(erc20Token).safeTransferFrom(address(this), _to, _amount);
                return;
            }
        }
        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public override {
        require(
            factorialModules[_msgSender()] ||
            _from == _msgSender() || _from == cache.caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );
        for (uint i = 0; i < _ids.length; i++) {
            uint id = _ids[i];
            uint amount = _amounts[i];
            if (_from == cache.caller) {
                cache.inputValue += tokenization.getValue(id, amount);
            } else if (_to == cache.caller) {
                cache.outputValue += tokenization.getValue(id, amount);
            }
            if (id >> 160 == 0) {
                address erc20Token = address(uint160(id));
                if (_from == cache.caller || factorialModules[_from]) {
                    if (_to == cache.caller || factorialModules[_to]) {
                        IERC20Upgradeable(erc20Token).safeTransferFrom(_from, _to, amount);
                    } else {
                        IERC20Upgradeable(erc20Token).safeTransferFrom(_from, address(this), amount);
                        _mint(_to, id, amount, "");
                    }
                    _amounts[i] = 0;
                } else if (_to == cache.caller || factorialModules[_to]) {
                    _burn(_from, id, amount);
                    IERC20Upgradeable(erc20Token).safeTransferFrom(address(this), _to, amount);
                    _amounts[i] = 0;
                }
            }
        }
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }
}
