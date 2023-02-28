// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBorrowable {
    function borrowCallback() external returns (uint256, uint256);

    function repayCallback(
        uint256 tokenId,
        uint256 tokenAmount
    ) external returns (uint256, uint256);
}
