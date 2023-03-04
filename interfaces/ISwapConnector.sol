// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISwapConnector {
    function mint(uint[] calldata _tokens, uint[] calldata _amounts) external returns (uint lpAmount);

    function burn(uint[] calldata _tokens, uint _amount) external returns (uint amountA, uint amountB);

    function depositNew(uint _pid, uint _amount) external returns (uint tokenId);

    function depositExist(uint _tokenId, uint _amount) external;

    function withdraw(uint _tokenId, uint _amount) external;

    function getPoolId(uint _tokenA, uint _tokenB) external view returns (uint256);

    function getLP(uint _tokenA, uint _tokenB) external view returns (uint256);

    function getUnderlyingLp(uint256 _tokenId) external view returns (uint256);

    function getUnderlyingAssets(uint256 _lp) external view returns (uint256, uint256);

    function getNextTokenId(uint _pid) external view returns (uint256);

    function getReserves(uint _tokenA, uint _tokenB) external view returns (uint, uint);

    function optimalSwapAmount(
        uint tokenA,
        uint tokenB,
        uint amountA,
        uint amountB
    ) external returns (uint swapAmt, bool isReversed);
}
