// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/IERC20Ex.sol";
import "../../../interfaces/IPriceOracle.sol";
import "../../../interfaces/external/IUniswapV2Pair.sol";

contract UniswapV2Oracle is IPriceOracle {
    IPriceOracle public immutable source;

    constructor(address _source) {
        source = IPriceOracle(_source);
    }

    using MathUpgradeable for uint256;

    /// ----- ADMIN FUNCTIONS -----
    /// @dev Get token price using oracle.
    function getPrice(address) external pure returns (uint) {
        revert("Not supported");
    }

    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    /// @param _pair Source pool address
    function getPrice(address _token, address _pair) external view returns (uint) {
        (uint rA, uint rB,) = IUniswapV2Pair(_pair).getReserves();
        address tokenA = IUniswapV2Pair(_pair).token0();
        address tokenB = IUniswapV2Pair(_pair).token1();

        uint decimals = IERC20Ex(_token).decimals();

        if (tokenA == _token) {
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
