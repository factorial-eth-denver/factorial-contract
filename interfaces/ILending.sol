// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ILending {
    struct BorrowInfo {
        address debtAsset;
        uint256 debtAmount;
        uint256 startTime;
    }

    function getBorrowInfo(
        uint256 _id
    ) external view returns (BorrowInfo memory);

    function getDebt(uint256 _id) external view returns (uint256, uint256);

    function calcFee(uint256 _id) external view returns (uint256);

    function borrowAndCallback(uint256 tokenId, address _asset, uint256 _amount) external returns (uint256);
    
    function repayAndCallback(uint256 _debtId) external;

    function liquidate(uint256 _deptId) external;
}
