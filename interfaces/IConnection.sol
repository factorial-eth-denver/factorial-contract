// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IConnection {
    function execute(address _target, bytes calldata _data) external returns (bytes memory);
}
