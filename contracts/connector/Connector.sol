// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/external/IMiniChef.sol";
import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";

import "./library/ConnectionBitmap.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/IAsset.sol";

contract Connector is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ConnectionBitmap for mapping(uint24 => uint256);

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize() external initializer {
        __Ownable_init();
    }
}
