// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBorrowable {
    function borrowCallback() external;

    function repayCallback() external;
}
