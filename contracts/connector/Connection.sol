// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";

import "hardhat/console.sol";
contract Connection is IConnection{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IConnectionPool public connectionPool;

    constructor() {
        connectionPool = IConnectionPool(msg.sender);
    }

    /// @dev Throws if called by not router.
    modifier checkAuth() {
        require(connectionPool.isRegisteredConnector(msg.sender), 'Not registered');
        _;
    }

    /// @dev Call to the target using the given data.
    /// @param _target The target external DEFI contract address.
    /// @param _data The data used in the call.
    function execute(address _target, bytes calldata _data) external checkAuth returns (bytes memory){
        (bool ok, bytes memory returndata) = _target.delegatecall(_data);
        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert('bad connection call');
            }
        }
        return returndata;
    }

    function doTransfer(address _token, address _to, uint _amount) external {
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }
}
