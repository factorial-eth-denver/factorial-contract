// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITriggerLogic {
    function check(
        uint256 initialValue,
        uint256 currentValue,
        bytes calldata
    ) external returns (bool);
}
