// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../../interfaces/IPriceOracle.sol";

contract SimplePriceOracle is IPriceOracle, OwnableUpgradeable, UUPSUpgradeable {
    mapping(address => uint) public prices; // Mapping from token to price. Price precision 1e18.

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() public initializer {
        __Ownable_init();
    }

    /// ----- ADMIN FUNCTIONS -----
    function setPrice(address token, uint256 price) external onlyOwner {
        require(price != 0, 'SimplePriceValuation setPrice: Invalid input price');
        prices[token] = price;
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    function getPrice(address _token) external override view returns (uint256 price) {
        price = prices[_token];
        require(price != 0, 'SimplePriceValuation getPrice: Invalid price');
    }
}
