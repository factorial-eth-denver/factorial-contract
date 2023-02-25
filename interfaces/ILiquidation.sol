// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILiquidation {
    function liquidate(uint tokenId, bytes memory param) external;
}
