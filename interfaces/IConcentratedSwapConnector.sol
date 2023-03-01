// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IConcentratedDexConnector {
    function mint(
        uint[] calldata _tokens,
        uint[] calldata _amounts,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper
    ) external returns (uint tokenId);

    function burn(
        uint256 _tokenId,
        uint128 _liquidity
    ) external returns (uint amountA, uint amountB);
}
