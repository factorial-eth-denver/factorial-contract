// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IConnection.sol";
import "../library/ConnectionBitmap.sol";

contract ConnectionBalancer is IConnection {
    using ConnectionBitmap for mapping(uint8 => uint256);

    struct ConnectionInfo {
    }

    mapping(address => address) public connectors;
    mapping(uint8 => uint256) public connectionBitMap;
    mapping(uint16 => ConnectionInfo) public connectionInfos;

    mapping(address => address) public oracles; // Mapping from token to oracle source

    /// @dev Call to the target using the given data.
    /// @param _target The target defi address
    /// @param _data The data used in the call.
    function execute(address _target, bytes calldata _data) external {
        IConnection(connection).execute(_target, _data);
    }
}
