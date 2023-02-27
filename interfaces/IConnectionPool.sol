// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IConnectionPool {
    function isRegisteredConnector(address _connector) external view returns (bool);
    function getConnectionAddress(uint _connectionId) external view returns (address);
    function getConnectionMax() external view returns (uint);
}
