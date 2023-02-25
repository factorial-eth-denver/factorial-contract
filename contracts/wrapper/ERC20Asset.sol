// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/IWrapper.sol";
import "../../interfaces/IPriceOracle.sol";

contract ERC20Asset is IWrapper, OwnableUpgradeable {
    IPriceOracle public oracle;

    function initialize(address _oracleRouter) public initializer {
        __Ownable_init();
        oracle = IPriceOracle(_oracleRouter);
    }

    function wrap(bytes memory param) external override {
        revert('Not supported');
    }

    function unwrap(uint tokenId, uint amount) external override {
        revert('Not supported');
    }

    function getValue(uint tokenId, uint amount) external view override returns (uint) {
        return oracle.getPrice(address(uint160(tokenId))) * amount;
    }
}
