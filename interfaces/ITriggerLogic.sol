// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITriggerLogic {
    function check(
        bytes calldata
    ) external returns (bool);
}
