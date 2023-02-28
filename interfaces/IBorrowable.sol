// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBorrowable {
    function borrowCallback() external returns (uint256, uint256);

    function repayCallback() external returns (uint256, uint256);
}
