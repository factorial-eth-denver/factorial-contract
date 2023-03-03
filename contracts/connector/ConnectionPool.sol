// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "../../interfaces/IConnectionPool.sol";

import "./library/ConnectionBitmap.sol";
import "../utils/FactorialContext.sol";
import "./Connection.sol";

contract ConnectionPool is IConnectionPool, OwnableUpgradeable {
    using ClonesUpgradeable for address;
    using ConnectionBitmap for mapping(uint256 => uint256);

    mapping(uint256 => uint256) public connectionBitMap;

    IAsset asset;

    uint256 public nextConnectionId;
    uint256 public lastConnectorId;
    mapping(address => uint256) public connectors;
    mapping(uint256 => address) public connections;
    address public connectionImpl;

    function initialize(address _asset) external initializer{
        __Ownable_init();
        asset = IAsset(_asset);
    }

    /// @dev Register connector.
    /// @param _connector External defi connector address
    function registerConnector(address _connector) external onlyOwner {
        lastConnectorId ++;
        connectors[_connector] = lastConnectorId;
    }

    function increaseConnection(uint n) external {
        address[] memory param = new address[](n);
        require(n <= 20, 'Over gas limit');
        require(n >= 1, 'Under minimum');
        if (nextConnectionId == 0) {
            connectionImpl = address(new Connection());
            connections[0] = connectionImpl;
            param[n-1] = connectionImpl;
            nextConnectionId ++;
            n --;
        }
        while (n > 0) {
            connections[nextConnectionId] = connectionImpl.clone();
            param[n-1] = connectionImpl;
            nextConnectionId ++;
            n --;
        }
        asset.registerFactorialModules(param);
    }

    function isRegisteredConnector(address _connector) external override view returns (bool) {
        return connectors[_connector] != 0;
    }

    function getConnectionAddress(uint24 _connectionId) external override view returns (address) {
        return connections[_connectionId];
    }

    function getConnectionMax() external override view returns (uint){
        return nextConnectionId;
    }
}
