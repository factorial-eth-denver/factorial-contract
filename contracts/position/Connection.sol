// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Connection {
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
    function execute(bytes calldata _data) external onlyBalancer {
        executeInternal(_data);
    }

    /// @dev Call batch to the target using the given data array.
    /// @param _dataArray The data array used in the call.
    function executeBatch(bytes[] calldata _dataArray) external onlyBalancer {
        for (uint256 idx = 0; idx < _dataArray.length; idx ++) {
            executeInternal(dex, _dataArray[idx]);
        }
    }

    /// @dev Internal function call to the target using the given data.
    /// @param _target The target contract address to call.
    /// @param _data The data used in the call.
    function executeInternal(address _target, bytes calldata _data) internal {
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
    }
}
