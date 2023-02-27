// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/IERC20Ex.sol";
import "../../../interfaces/IPriceOracle.sol";
import "../../../interfaces/external/IUniswapV2Pair.sol";

contract UniswapV2Oracle is IPriceOracle {
    IPriceOracle public immutable source;

    constructor(address _source) public {
        source = IPriceOracle(_source);
    }

    using MathUpgradeable for uint256;

    function getPrice(address token) external view returns (uint price) {
        return 0;
    }

    function getPrice(address token, address pair) external view returns (uint) {
        (uint rA, uint rB,) = IUniswapV2Pair(pair).getReserves();
        address tokenA = IUniswapV2Pair(pair).token0();
        address tokenB = IUniswapV2Pair(pair).token1();

        uint decimals = IERC20Ex(token).decimals();

        if (tokenA == token) {
            if (decimals > 18) {
                rB = rB * (10 ** (decimals - 18));
            } else {
                rA = rA * (10 ** (18 - decimals));
            }
            return rB * (source.getPrice(tokenB)) / (rA);
        } else {
            if (decimals > 18) {
                rA = rA * (10 ** (18 - decimals));
            } else {
                rB = rB * (10 ** (decimals - 18));
            }
            return rA * (source.getPrice(tokenA)) / rB;
        }
    }
}
