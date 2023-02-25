// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IPriceOracle {
    function getPrice(address token) external view returns (uint price);
}
