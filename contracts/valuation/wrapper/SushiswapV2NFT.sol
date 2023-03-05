// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/IPriceOracle.sol";
import "../../../interfaces/IConnectionPool.sol";
import "../../../interfaces/IERC20Ex.sol";

import "../../../interfaces/external/IUniswapV2Pair.sol";
import "../../../interfaces/external/IMiniChef.sol";

contract SushiswapV2NFT is OwnableUpgradeable, IWrapper {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    ITokenization public tokenization;
    IMiniChef public farm;
    IERC20Upgradeable public sushi;
    IConnectionPool public connectionPool;
    uint256 private sequentialN;

    /// @dev Throws if called by not router.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _farm, address _connectionPool) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        farm = IMiniChef(_farm);
        sushi = IERC20Upgradeable(farm.SUSHI());
        connectionPool = IConnectionPool(_connectionPool);
    }

    function wrap(address, uint24, bytes calldata) external pure override returns (uint) {
        revert('Not supported');
    }

    function unwrap(address, uint, uint) external pure override {
        revert('Not supported');
    }

    function getValue(uint256 tokenId, uint256) public view override returns (uint){
        uint256 poolId = uint256(uint80(tokenId));
        uint24 connectionId = uint24(tokenId >> 80);
        address connection = connectionPool.getConnectionAddress(connectionId);
        (uint256 amount,) = farm.userInfo(poolId, connection);

        address lpToken = farm.lpToken(poolId);
        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();
        uint256 totalSupply = IUniswapV2Pair(lpToken).totalSupply();
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(lpToken).getReserves();
        uint256 px0 = tokenization.getValue(uint256(uint160(token0)), 1);
        uint256 px1 = tokenization.getValue(uint256(uint160(token1)), 1);
        return ((r0 * px0) + (r1 * px1)) * amount / totalSupply;
    }

    function getValueAsCollateral(address _lendingProtocol, uint256 tokenId, uint256 amount) public view override returns (uint){
        (uint256 amount,) = farm.userInfo(uint256(uint80(tokenId)), connectionPool.getConnectionAddress(uint24(tokenId >> 80)));

        address lpToken = farm.lpToken(uint256(uint80(tokenId)));
        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();
        uint256 totalSupply = IUniswapV2Pair(lpToken).totalSupply();
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(lpToken).getReserves();
        uint256 px0 = tokenization.getValueAsCollateral(_lendingProtocol,uint256(uint160(token0)), 1);
        uint256 px1 = tokenization.getValueAsCollateral(_lendingProtocol,uint256(uint160(token1)), 1);
        return ((r0 * px0) + (r1 * px1)) * amount / totalSupply;
    }


    function getValueAsDebt(address _lendingProtocol, uint256 tokenId, uint256 amount) public view override returns (uint){
        (uint256 amount,) = farm.userInfo(uint256(uint80(tokenId)), connectionPool.getConnectionAddress(uint24(tokenId >> 80)));

        address lpToken = farm.lpToken(uint256(uint80(tokenId)));
        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();
        uint256 totalSupply = IUniswapV2Pair(lpToken).totalSupply();
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(lpToken).getReserves();
        uint256 px0 = tokenization.getValueAsDebt(_lendingProtocol,uint256(uint160(token0)), 1);
        uint256 px1 = tokenization.getValueAsDebt(_lendingProtocol,uint256(uint160(token1)), 1);
        return ((r0 * px0) + (r1 * px1)) * amount / totalSupply;
    }

    function getNextTokenId(address, uint24) public pure override returns (uint) {
        revert('Not supported');
    }
}
