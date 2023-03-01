// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMortgage {
    function getDebt(uint _tokenId) external view returns (uint tokenId, uint amount);
    function repay(uint tokenId) external;
}
