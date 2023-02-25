// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/external/IUniswapV2Router.sol";
import "../../interfaces/IConnection.sol";

contract UniswapV2Connector is IUniswapV2Router {
    IUniswapV2Router public router;
    IConnection public connections;

    function initialize(address _router) public initializer {
        router = IUniswapV2Router(_router);
    }

    function factory() external pure returns (address) {
        return router.factory();
    }

    function WETH() external pure returns (address) {
        return router.WETH();
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint, uint, uint) {
        bytes memory callData = abi.encodeWithSignature(
            "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
            tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
        bytes memory returnData = connections.execute(callData);
        (uint amountA, uint amountB, uint liquidity) = abi.decode(_param, (uint, uint, uint));
        return (amountA, amountB, liquidity);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity){
        revert('Use Wrapped native token');
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint, uint) {
        bytes memory callData = abi.encodeWithSignature(
            "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)",
            tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
        bytes memory returnData = connections.execute(callData);
        (uint amountA, uint amountB) = abi.decode(_param, (uint, uint));
        return (amountA, amountB);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH) {
        revert('Use Wrapped native token');
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB) {
        bytes memory callData = abi.encodeWithSignature(
            "removeLiquidityWithPermit(address,address,uint256,uint256,uint256,address,uint256,bool,uint8,bytes32,bytes32)",
            tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline, approveMax, v, r, s);
        bytes memory returnData = connections.execute(callData);
        (uint amountA, uint amountB) = abi.decode(_param, (uint, uint));
        return (amountA, amountB);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH) {
        revert('Use Wrapped native token');
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        return router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        return router.swapExactTokensForTokens(amountOut, amountInMax, path, to, deadline);
    }

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        revert('Use Wrapped native token');
    }

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        revert('Use Wrapped native token');
    }

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        revert('Use Wrapped native token');
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        revert('Use Wrapped native token');
    }

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB) {
        return router.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut) {
        return router.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn) {
        return router.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] calldata path)
    external
    view
    returns (uint[] memory amounts) {
        return router.getAmountsOut(amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] calldata path)
    external
    view
    returns (uint[] memory amounts) {
        return router.getAmountsIn(amountOut, path);
    }
}
