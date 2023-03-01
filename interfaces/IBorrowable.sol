// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IBorrowable {

    struct BorrowCache {
        bool init;
        address debtAsset;
        uint256 debtAmount;
        address collateralAsset;
        uint256 collateralAmount;
    }

    function borrowCallback() external;

    function repayCallback() external returns (uint256, uint256);
}
