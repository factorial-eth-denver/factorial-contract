// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMasterChef {
    function sushi() external view returns (address);

    function poolInfo(uint pid)
    external
    view
    returns (
        address lpToken,
        uint allocPoint,
        uint lastRewardBlock,
        uint accSushiPerShare
    );

    function deposit(uint pid, uint amount) external;

    function withdraw(uint pid, uint amount) external;

    function userInfo(uint pid, address user) external view returns (uint amount, uint rewardDebt);
}
