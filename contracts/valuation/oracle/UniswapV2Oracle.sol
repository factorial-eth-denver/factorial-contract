// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/IERC20Ex.sol";
import "../../../interfaces/IPriceOracle.sol";
import "../../../interfaces/external/IUniswapV2Pair.sol";

contract UniswapV2Oracle is OwnableUpgradeable, IPriceOracle {
    mapping(address => address) sourceLp;
    IPriceOracle public source;

    function initialize(address _source) public initializer {
        __Ownable_init();
        source = IPriceOracle(_source);
    }

    using MathUpgradeable for uint256;

    /// ----- ADMIN FUNCTIONS -----
    function setSourceLP(address _token, address _lp) external onlyOwner{
        sourceLp[_token] = _lp;
    }

    /// ----- VIEW FUNCTIONS ------
    /// @dev Get token price using oracle.
    function getPrice(address _token) public view override returns (uint){
        if (sourceLp[_token] != address(0)) {
            return getPrice(_token, sourceLp[_token]);
        }
        address token0 = IUniswapV2Pair(_token).token0();
        address token1 = IUniswapV2Pair(_token).token1();
        uint totalSupply = IUniswapV2Pair(_token).totalSupply();
        (uint r0, uint r1,) = IUniswapV2Pair(_token).getReserves();
        uint sqrtK = r0 * (r1.sqrt()) * (2 ** 112) / totalSupply;
        uint px0 = IPriceOracle(source).getPrice(token0);
        uint px1 = IPriceOracle(source).getPrice(token1);
        return sqrtK * 2 * (px0.sqrt()) / (2 ** 56) * (px1.sqrt()) / (2 ** 56);
    }


    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    /// @param _pair Source pool address
    function getPrice(address _token, address _pair) public view returns (uint) {
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
