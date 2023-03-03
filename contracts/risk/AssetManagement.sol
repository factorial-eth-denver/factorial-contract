// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./FactorialAsset.sol";

contract AssetManagement is FactorialAsset, OwnableUpgradeable, UUPSUpgradeable {
    using SafeCastUint256 for uint256;

    /// ----- CACHE STATES -----
    struct VariableCache {
        uint256 maximumLoss;
        uint256 inputValue;
        uint256 outputValue;
    }

    VariableCache public cache;

    /// ----- SETTING STATES -----
    address public router;

    /// @dev Throws if called by not factorial module.
    modifier onlyFactorialModule() override {
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

    /// @dev Caching states for financial soundness.
    /// @param _maximumLoss The maximum loss of this tx.
    /// @param _caller The external caller of factorial tx.
    function beforeExecute(uint _maximumLoss, address _caller) external onlyRouter {
        require(caller == address(0), 'Locked');
        caller = _caller;
        cache.maximumLoss = _maximumLoss;
    }

    /// @dev Validate caller's input/output assets.
    function afterExecute() external onlyRouter {
        require(cache.outputValue + cache.maximumLoss > cache.inputValue, 'Over slippage');
        caller = address(0);
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
            _from == _msgSender() || _from == caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );
        if (_from == caller) {
            cache.inputValue += tokenization.getValue(_id, _amount);
        } else if (_to == caller) {
            cache.outputValue += tokenization.getValue(_id, _amount);
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
            _from == _msgSender() || _from == caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );

        for (uint256 i = 0; i < _ids.length; ++i) {
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];
            if (_from == caller) {
                cache.inputValue += tokenization.getValue(id, amount);
            } else if (_to == caller) {
                cache.outputValue += tokenization.getValue(id, amount);
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

    /// @dev Mint ERC1155 token & track factorial caller's input. Only called by factorial modules.
    /// @param _to The receiver address.
    /// @param _tokenId The token id to mint.
    /// @param _amount The amount of minting.
    function mint(address _to, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_to == caller) {
            cache.outputValue += tokenization.getValue(_tokenId, _amount);
        }
        _mint(_to, _tokenId, _amount, "");
    }

    /// @dev Burn ERC1155 token & track factorial caller's output. Only called by factorial modules.
    /// @param _from The payer address.
    /// @param _tokenId The token id to burn.
    /// @param _amount The amount of burn.
    function burn(address _from, uint _tokenId, uint _amount) public onlyFactorialModule {
        if (_from == caller) {
            cache.inputValue += tokenization.getValue(_tokenId, _amount);
        }
        _burn(_from, _tokenId, _amount);
    }

    /// @dev If account is ERC20 holders, return ERC20 balance else return ERC1155 balance.
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        if (id >> 160 == 0) {
            if (account == caller || factorialModules[account]) {
                return IERC20Upgradeable(id.toAddress()).balanceOf(account);
            }
        }
        return super.balanceOf(account, id);
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Return msg sender. If sender is router, return factorial tx caller.
    function _msgSender() internal view override returns (address) {
        if (msg.sender == router) {
            return caller;
        }
        return msg.sender;
    }
}
