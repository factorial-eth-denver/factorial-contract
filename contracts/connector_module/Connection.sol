// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";

contract Connection is IConnection{
    IConnectionPool public connectionPool;

    /// @dev Throws if called by not router.
    modifier checkAuth() {
        require(connectionPool.isRegisteredConnector(msg.sender), 'Not registered');
        _;
    }

    /// @dev Call to the target using the given data.
    /// @param _target The target external DEFI contract address.
    /// @param _data The data used in the call.
    function execute(address _target, bytes calldata _data) external checkAuth returns (bytes memory){
        (bool ok, bytes memory returndata) = _target.call(_data);
        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert('bad execute call');
            }
        }
        return returndata;
    }
}
