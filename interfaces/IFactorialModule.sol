// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IFactorialModule {
    function doTransfer(address _token, address _to, uint _amount) external;
}
