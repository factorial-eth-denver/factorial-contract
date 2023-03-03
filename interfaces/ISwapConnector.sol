// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISwapConnector {
    function mint(uint[] calldata _tokens, uint[] calldata _amounts) external returns (uint lpAmount);

    function burn(uint[] calldata _tokens, uint _amount) external returns (uint amountA, uint amountB);

    function depositNew(uint _pid, uint _amount) external returns (uint tokenId);

    function depositExist(uint _tokenId, uint _amount) external;

    function withdraw(uint _tokenId, uint _amount) external;
}