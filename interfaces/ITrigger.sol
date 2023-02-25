// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITrigger {
    function trigger(uint tokenId, bytes memory param) external;
}
