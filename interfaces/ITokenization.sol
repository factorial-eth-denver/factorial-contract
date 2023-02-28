// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITokenization {
    function wrap(uint24 _wrapperTokenType, bytes calldata param) external returns (uint);

    function unwrap(uint _tokenId, uint _amount) external;

    function getValue(uint tokenId, uint amount) external view returns (uint);
}
