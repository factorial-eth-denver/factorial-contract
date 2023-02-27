// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../../interfaces/IPriceOracle.sol";

contract OracleRouter is IPriceOracle, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => address) public oracles; // Mapping from token to oracle source

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer {
        __Ownable_init();
    }

    function setRoute(address[] calldata tokens, address[] calldata targetOracles) external onlyOwner {
        require(tokens.length == targetOracles.length, 'inconsistent length');
        for (uint i = 0; i < tokens.length; i++) {
            oracles[tokens[i]] = targetOracles[i];
        }
    }

    function getPrice(address token) external view override returns (uint) {
        require(oracles[token] != address(0), 'Unregistered token');
        uint price = IPriceOracle(oracles[token]).getPrice(token);
        return price;
    }
}
