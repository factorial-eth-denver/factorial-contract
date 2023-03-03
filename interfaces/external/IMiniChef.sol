// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IMiniChef {
    function SUSHI() external view returns (address);

    function poolInfo(uint pid)
    external
    view
    returns (
        uint allocPoint,
        uint lastRewardTime,
        uint accSushiPerShare
    );

    function lpToken(uint pid) external view returns(address);

    function deposit(uint pid, uint amount, address to) external;

    function withdraw(uint pid, uint amount, address to) external;

    function userInfo(uint pid, address user) external view returns (uint amount, uint rewardDebt);
}
