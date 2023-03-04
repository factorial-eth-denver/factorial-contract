// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../connector/library/SafeCastUint256.sol";

import "../../interfaces/IFactorialModule.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/ITrigger.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/IAsset.sol";

contract FactorialAsset is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeCastUint256 for uint256;

    /// ----- CACHE STATES -----
    address public caller;

    /// ----- INIT STATES -----
    ITokenization public tokenization;

    /// ----- SETTING STATES -----
    mapping(address => bool) public factorialModules;
    mapping(uint256 => address) public ownerOf;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    /// @dev Throws if called by not factorial module.
    modifier onlyFactorialModule() virtual {
        require(factorialModules[_msgSender()], 'Only factorial module');
        _;
    }

    /// @dev Register whitelisted factorial modules. This modules can hold & transfer ERC20 asset.
    /// @param _factorialModules The factorial modules to register.
    function registerFactorialModules(address[] calldata _factorialModules) external onlyFactorialModule {
        for (uint256 i = 0; i < _factorialModules.length; ++i) {
            factorialModules[_factorialModules[i]] = true;
        }
    }

    /// ----- VIEW FUNCTIONS -----
    ///
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
        interfaceId == type(IERC1155Upgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
    public
    view
    virtual
    override
    returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev No approve in Factorial assets.
     */
    function setApprovalForAll(address, bool) external pure virtual override {
        revert('Not support approve');
    }

    function isApprovedForAll(address, address) external pure virtual returns (bool){
        revert('Not support approve');
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
    ) public virtual override {
        require(
            factorialModules[_msgSender()] ||
            _from == _msgSender() || _from == caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );
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
    ) public virtual override {
        require(
            factorialModules[_msgSender()] ||
            _from == _msgSender() || _from == caller,
            "ERC1155: caller is not token owner or caller or factorial"
        );
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    /**
     * @dev This function override {ERC1155 _safeTransferFrom}.
     * Include ERC20 converter.
     */
    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) internal {
        require(_to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        if (_amount == 0) {
            return;
        }
        emit TransferSingle(operator, _from, _to, _id, _amount);

        if ((_id >> 160) == 0) {
            address externalToken = _id.toAddress();
            if (_from == caller) {
                if (factorialModules[_to]) {
                    IERC20Upgradeable(externalToken).safeTransferFrom(_from, _to, _amount);
                } else {
                    IERC20Upgradeable(externalToken).safeTransferFrom(_from, address(this), _amount);
                    _balances[_id][_to] += _amount;
                }
                return;
            } else if (factorialModules[_from]) {
                if (_to == caller || factorialModules[_to]) {
                    IFactorialModule(_from).doTransfer(externalToken, _to, _amount);
                } else {
                    IFactorialModule(_from).doTransfer(externalToken, address(this), _amount);
                    _balances[_id][_to] += _amount;
                }
                return;
            } else if (_to == caller || factorialModules[_to]) {
                uint256 fromBalance = _balances[_id][_from];
                require(fromBalance >= _amount, "ERC1155: insufficient balance for transfer");
                _balances[_id][_from] = fromBalance - _amount;
                IERC20Upgradeable(externalToken).safeTransfer(_to, _amount);
                return;
            }
        }
        uint256 fromBalance = _balances[_id][_from];
        require(fromBalance >= _amount, "ERC1155: insufficient balance for transfer");
        _balances[_id][_from] = fromBalance - _amount;
        _balances[_id][_to] += _amount;

        uint256[] memory ids = _asSingletonArray(_id);
        uint256[] memory amounts = _asSingletonArray(_amount);
        _afterTokenTransfer(operator, _from, _to, ids, amounts, _data);
        _doSafeTransferAcceptanceCheck(operator, _from, _to, _id, _amount, _data);
    }

    /**
     * @dev This function override {ERC1155-_safeTransferFrom}.
     * Include ERC20 converter.
     */
    function _safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual {
        require(_ids.length == _amounts.length, "ERC1155: ids and amounts length mismatch");
        require(_to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        emit TransferBatch(operator, _from, _to, _ids, _amounts);

        bool onlyERC20Transfer = true;
        for (uint256 i = 0; i < _ids.length; ++i) {
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];
            if (amount == 0) {
                continue;
            }
            if ((id >> 160) == 0) {
                address externalToken = id.toAddress();
                if (_from == caller) {
                    if (factorialModules[_to]) {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, _to, amount);
                    } else {
                        IERC20Upgradeable(externalToken).safeTransferFrom(_from, address(this), amount);
                        _balances[id][_to] += amount;
                    }
                    continue;
                } else if (factorialModules[_from]) {
                    if (_to == caller || factorialModules[_to]) {
                        IFactorialModule(_from).doTransfer(externalToken, _to, amount);
                    } else {
                        IFactorialModule(_from).doTransfer(externalToken, address(this), amount);
                        _balances[id][_to] += amount;
                    }
                    continue;
                } else if (_to == caller || factorialModules[_to]) {
                    uint256 fromBalance = _balances[id][_from];
                    require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
                    _balances[id][_from] = fromBalance - amount;
                    IERC20Upgradeable(externalToken).safeTransfer(_to, amount);
                    continue;
                }
            }
            onlyERC20Transfer = false;
            uint256 fromBalance = _balances[id][_from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            _balances[id][_from] = fromBalance - amount;
            _balances[id][_to] += amount;
            if (id >> 255 == 1) ownerOf[id] = _to;
        }

        if (onlyERC20Transfer) {
            return;
        }

        _afterTokenTransfer(operator, _from, _to, _ids, _amounts, _data);
        _doSafeBatchTransferAcceptanceCheck(operator, _from, _to, _ids, _amounts, _data);
    }


    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
    unchecked {
        _balances[id][from] = fromBalance - amount;
    }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /// @dev After transfer, write ownerOf like ERC721.
    function _afterTokenTransfer(
        address,
        address,
        address to,
        uint256[] memory ids,
        uint256[] memory,
        bytes memory
    ) internal {
        for (uint256 i; i < ids.length; ++i) {
            if (ids[i] >> 255 == 1) {
                ownerOf[ids[i]] = to;
            }
        }
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
