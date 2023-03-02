// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../connector/library/SafeCastUint256.sol";

import "../../interfaces/IFactorialModule.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/ITrigger.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/IAsset.sol";

contract AssetManagement is ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUint256 for uint256;

    /// ----- VARIABLE STATES -----
    struct VariableCache {
        address caller;
        uint256 maximumLoss;
        uint256 inputValue;
        uint256 outputValue;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;

    /// ----- INIT STATES -----
    ITokenization public tokenization;
    address public router;

    /// ----- SETTING STATES -----
    mapping(address => bool) public factorialModules;
    mapping(uint256 => address) public ownerOf;


    /// @dev Throws if called by not factorial module.
    modifier onlyFactorialModule() {
        require(factorialModules[_msgSender()] || _msgSender() == owner(), 'Only factorial module');
        _;
    }

    /// @dev Throws if called by not router.
    modifier onlyRouter() {
        require(msg.sender == router, 'Only router');
        _;
    }

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @dev Initialize asset management contract
    /// @param _router The factorial router contract.
    /// @param _tokenization The factorial tokenization contract.
    function initialize(address _router, address _tokenization) external initializer {
        __Ownable_init();
        router = _router;
        tokenization = ITokenization(_tokenization);
    }

    /// @dev Register whitelisted factorial modules. This modules can hold & transfer ERC20 asset.
    /// @param _factorialModules The factorial modules to register.
    function registerFactorialModules(address[] calldata _factorialModules) external onlyFactorialModule {
        for (uint i = 0; i < _factorialModules.length; i++) {
            factorialModules[_factorialModules[i]] = true;
        }
    }

    /// @dev Mint ERC1155 token & track factorial caller's input. Only called by factorial modules.
    /// @param _to The receiver address.
    /// @param _tokenId The token id to mint.
    /// @param _amount The amount of minting.
    function mint(address _to, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_to == cache.caller) {
            cache.outputValue += tokenization.getValue(_tokenId, _amount);
        }
        _mint(_to, _tokenId, _amount, "");
    }

    /// @dev Burn ERC1155 token & track factorial caller's output. Only called by factorial modules.
    /// @param _from The payer address.
    /// @param _tokenId The token id to burn.
    /// @param _amount The amount of burn.
    function burn(address _from, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_from == cache.caller) {
            cache.inputValue += tokenization.getValue(_tokenId, _amount);
        }
        _burn(_from, _tokenId, _amount);
    }

    /// @dev Caching states for financial soundness.
    /// @param _maximumLoss The maximum loss of this tx.
    /// @param _caller The external caller of factorial tx.
    function beforeExecute(uint _maximumLoss, address _caller) external onlyRouter {
        require(cache.caller == address(0), 'Locked');
        cache.caller = _caller;
        cache.maximumLoss = _maximumLoss;
    }

    /// @dev Validate caller's input/output assets.
    function afterExecute() external onlyRouter {
        require(cache.outputValue + cache.maximumLoss > cache.inputValue, 'Over slippage');
        delete cache;
    }

    /**
     * @dev This function override {ERC1155-safeTransferFrom}.
     * Include tracking caller's input/outpunt asset & ERC20 converter.
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
            address externalToken = _id.toAddress();
            if (_from == cache.caller) {
                if (factorialModules[_to]) {
                    IERC20Upgradeable(externalToken).safeTransferFrom(_from, _to, _amount);
                } else {
                    IERC20Upgradeable(externalToken).safeTransferFrom(_from, address(this), _amount);
                    _mint(_to, _id, _amount, "");
                }
                return;
            } else if (factorialModules[_from]) {
                if (_to == cache.caller || factorialModules[_to]) {
                    IFactorialModule(_from).doTransfer(externalToken, _to, _amount);
                } else {
                    IFactorialModule(_from).doTransfer(externalToken, address(this), _amount);
                    _mint(_to, _id, _amount, "");
                }
                return;
            } else if (_to == cache.caller || factorialModules[_to]) {
                _burn(_from, _id, _amount);
                IERC20Upgradeable(externalToken).safeTransfer(_to, _amount);
                return;
            }
        }
        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    /**
     * @dev This function override {ERC1155-safeBatchTransferFrom}.
     * Include tracking caller's input/outpunt asset & ERC20 converter.
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
                if (_from == cache.caller) {
                    if (factorialModules[_to]) {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, _to, amount);
                    } else {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, address(this), amount);
                        _mint(_to, id, amount, "");
                    }
                    _amounts[i] = 0;
                } else if (factorialModules[_from]) {
                    if (_to == cache.caller || factorialModules[_to]) {
                        IFactorialModule(_from).doTransfer(externalToken, _to, amount);
                    } else {
                        IFactorialModule(_from).doTransfer(externalToken, address(this), amount);
                        _mint(_to, id, amount, "");
                    }
                    _amounts[i] = 0;
                } else if (_to == cache.caller || factorialModules[_to]) {
                    _burn(_from, id, amount);
                    IERC20Upgradeable(externalToken).safeTransfer(_to, amount);
                    _amounts[i] = 0;
                }
            }
        }
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    /// @dev The helper function for transfer with erc20 transfer.
    function safeTransferFrom(
        address _from,
        address _to,
        address _id,
        uint256 _amount
    ) public {
        safeTransferFrom(_from, _to, uint256(uint160(_id)), _amount, '');
    }

    /// ----- OVERRIDE FUNCTIONS -----
    /// @dev After transfer, write ownerOf like ERC721.
    function _afterTokenTransfer(
        address,
        address,
        address to,
        uint256[] memory ids,
        uint256[] memory,
        bytes memory
    ) internal override {
        for (uint i; i < ids.length; i++) {
            if (ids[i] >> 255 == 1) {
                ownerOf[ids[i]] = to;
            }
        }
    }

    /// @dev If account is ERC20 holders, return ERC20 balance else return ERC1155 balance.
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        if (id >> 160 == 0) {
            if (account == cache.caller || factorialModules[account]) {
                return IERC20Upgradeable(id.toAddress()).balanceOf(account);
            }
        }
        return super.balanceOf(account, id);
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Return msg sender. If sender is router, return factorial tx caller.
    function _msgSender() internal view override returns (address) {
        if (msg.sender == router) {
            return cache.caller;
        }
        return msg.sender;
    }

    /// @dev Return caller of factorial tx.
    function caller() external view returns (address) {
        return cache.caller;
    }
}
