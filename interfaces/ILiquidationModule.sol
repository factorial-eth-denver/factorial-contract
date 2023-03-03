// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILiquidationModule {
    function execute(address liquidator, uint256 tokenId,  bytes calldata value) external;
}
