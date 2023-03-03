// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IRepayable {

    struct RepayCache {
        bool init;
        uint256 collateralAsset;
        uint256 collateralAmount;
        uint256 debtAsset;
        uint256 debtAmount;
    }


    function repayCallback() external;
}
