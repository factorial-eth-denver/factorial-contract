// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../connector/library/SafeCastUint256.sol";

import "../../interfaces/ITokenization.sol";
import "../../interfaces/ITrigger.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/IAsset.sol";

contract FactorialAsset is ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUint256 for uint256;

    struct VariableCache {
        address caller;
        uint256 maximumLoss;
        uint256 inputValue;
        uint256 outputValue;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    ITokenization public tokenization;

    /// ----- SETTING STATES -----
    mapping(address => bool) public factorialModules;
    address public router;

    /// @dev Throws if called by not factorial module.
    modifier onlyFactorialModule() {
        require(factorialModules[_msgSender()], 'Only factorial module');
        _;
    }

    /// @dev Throws if called by not router.
    modifier onlyRouter() {
        require(msg.sender == router, 'Only router');
        _;
    }

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _router, address _tokenization) external initializer {
        __Ownable_init();
        router = _router;
        tokenization = ITokenization(_tokenization);
    }

    function registerFactorialModules(address[] calldata _factorialModules) external onlyOwner {
        for (uint i = 0; i < _factorialModules.length; i++) {
            factorialModules[_factorialModules[i]] = true;
        }
    }

    function caller() external view returns (address) {
        return cache.caller;
    }

    function mint(address _to, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_to == cache.caller) {
            cache.outputValue += tokenization.getValue(_tokenId, _amount);
        }
        _mint(_to, _tokenId, _amount, "");
    }

    function burn(address _from, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_from == cache.caller) {
            cache.inputValue += tokenization.getValue(_tokenId, _amount);
        }
        _burn(_from, _tokenId, _amount);
    }

    function beforeExecute(uint _maximumLoss, address _caller) external onlyRouter {
        require(cache.caller == address(0), 'Locked');
        cache.caller = _caller;
        cache.maximumLoss = _maximumLoss;
    }

    function afterExecute() external onlyRouter {
        console.log(cache.outputValue);
        console.log(cache.inputValue);
        console.log(cache.maximumLoss);
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
        if ((_id >> 160) == 0) {
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
            if ((id >> 160) == 0) {
                address externalToken = id.toAddress();
                if (_from == cache.caller || factorialModules[_from]) {
                    if (_to == cache.caller || factorialModules[_to]) {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, _to, amount);
                    } else {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, address(this), amount);
                        _mint(_to, id, amount, "");
                    }
                    _amounts[i] = 0;
                } else if (_to == cache.caller || factorialModules[_to]) {
                    _burn(_from, id, amount);
                    IERC20Upgradeable(externalToken).safeTransferFrom(address(this), _to, amount);
                    _amounts[i] = 0;
                }
            }
        }
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    function safeTransferFrom(
        address _from,
        address _to,
        address _id,
        uint256 _amount
    ) public {
        safeTransferFrom(_from, _to, uint256(uint160(_id)), _amount, '');
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");

        if (id >> 160 == 0) {
            if (account == cache.caller || factorialModules[account]) {
                return IERC20Upgradeable(id.toAddress()).balanceOf(account);
            }
        }
        return balanceOf(account, id);
    }

    function _msgSender() internal view override returns (address) {
        if (msg.sender == router) {
            return cache.caller;
        }
        return msg.sender;
    }
}
