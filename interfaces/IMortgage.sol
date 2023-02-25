// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMortgage {
    function getDebt(uint tokenId) external view returns (uint tokenType, uint amount);
    function repay(uint tokenId) external;
}
