// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IPriceOracle.sol";

contract ERC20Asset is IWrapper, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IPriceOracle public oracle;

    function initialize(address _oracleRouter) public initializer {
        __Ownable_init();
        oracle = IPriceOracle(_oracleRouter);
    }

    function wrap(address, uint24, bytes memory) external pure override returns (uint) {
        revert('Not supported');
    }

    function unwrap(address, uint, uint) external pure override {
        revert('Not supported');
    }

    function getValue(uint tokenId, uint amount) external view override returns (uint) {
        return oracle.getPrice(address(uint160(tokenId))) * amount;
    }

    function getNextTokenId(address, uint24) public pure override returns (uint) {
        revert('Not supported');
    }
}
