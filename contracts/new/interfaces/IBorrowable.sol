// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBorrowable {
    function borrowCallback(uint256, uint256) external returns (uint256);

    function repayCallback(uint256, uint256) external returns (uint256);
}
