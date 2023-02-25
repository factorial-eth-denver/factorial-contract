// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWrapper {
    function wrap(bytes memory param) external;
    function unwrap(uint tokenId, uint amount) external;
    function getValue(uint tokenId, uint amount) external view returns (uint);
}
