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
    /// ----- ADMIN FUNCTIONS -----
    function setRoute(address[] calldata tokens, address[] calldata targetOracles) external onlyOwner {
        require(tokens.length == targetOracles.length, 'inconsistent length');
        for (uint256 i = 0; i < tokens.length; ++i) {
            oracles[tokens[i]] = targetOracles[i];
        }
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    function getPrice(address _token) external view override returns (uint) {
        require(oracles[_token] != address(0), 'Unregistered token');
        uint256 price = IPriceOracle(oracles[_token]).getPrice(_token);
        return price;
    }
}
