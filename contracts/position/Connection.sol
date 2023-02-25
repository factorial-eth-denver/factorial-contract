// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IConnection.sol";

contract Connection is IConnection{
    address public balancer;

    constructor() public {
        balancer = msg.sender;
    }

    /// @dev Throws if called by not router.
    modifier onlyRouter() {
        require(msg.sender == balancer, 'Only Balancer');
        _;
    }

    /// @dev Call to the target using the given data.
    /// @param _data The data used in the call.
    function execute(address _target, bytes calldata _data) external onlyBalancer returns (bytes){
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
