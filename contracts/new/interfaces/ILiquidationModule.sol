// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILiquidationModule {
    function execute() external returns (bool);
}
