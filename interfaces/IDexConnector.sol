// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDexConnector {
    function buy(uint _yourToken, uint _wantToken, uint _amount) external;

    function sell(uint _yourToken, uint _wantToken, uint _amount) external;
}
