// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint128.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';

import "../../utils/FactorialContext.sol";

import "../../../interfaces/external/IUniswapV3Factory.sol";
import "../../../interfaces/IDexConnector.sol";
import "../../../interfaces/IConcentratedSwapConnector.sol";
import "../../../interfaces/IConnectionPool.sol";
import "../../../interfaces/IConnection.sol";

import "../library/ConnectionBitmap.sol";
import "../library/SafeCastUint256.sol";

import "./library/OptimalSwap.sol";
import "./library/TickMathWithSpacing.sol";
import "./library/SafeCastExtend.sol";
import "./library/PositionKey.sol";
import "./library/LiquidityAmounts.sol";

/// @title Uniswap v3 auto rebalancing contract
contract UniswapV3Connector is IDexConnector, IConcentratedDexConnector, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastExtend for uint256;
    using SafeCastUint256 for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using ConnectionBitmap for mapping(uint24 => uint256);

    // @dev Uniswap v3 factory.
    IUniswapV3Factory public factory;
    IConnectionPool public connectionPool;
    uint public wrapperTokenType;
    mapping(uint24 => uint256) public connectionBitMap;

    struct VariableCache {
        address currentSwapPool;
        uint256 token0;
        uint256 token1;
    }

    /// ----- VARIABLE STATES -----
    VariableCache public cache;
    address public currentSwapPool;

    /// @dev Prevent calling a function from anyone except UniswapV3 current pool.
    modifier onlySwapPool() {
        require(msg.sender == cache.currentSwapPool, "onlyPool: Unauthorized.");
        _;
    }

    function initialize(
        address _asset,
        address _factory,
        address _connectionPool,
        uint _wrapperTokenType
    ) external initContext(_asset) {
        factory = IUniswapV3Factory(_factory);
        wrapperTokenType = _wrapperTokenType;
        connectionPool = IConnectionPool(_connectionPool);
    }

    /// @dev Uniswap v3 mint callback function with no data
    /// @param _amount0 amount of token0 for minting
    /// @param _amount1 amount of token1 for minting
    function uniswapV3MintCallback(
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata
    ) external onlySwapPool {
        if (_amount0 > 0) IERC20Upgradeable(cache.token0.toAddress()).safeTransfer(cache.currentSwapPool, _amount0);
        if (_amount1 > 0) IERC20Upgradeable(cache.token1.toAddress()).safeTransfer(cache.currentSwapPool, _amount1);
    }

    /// @dev Uniswap v3 swap callback function with no data
    /// @param _amount0Delta delta amount of token0 in swap
    /// @param _amount1Delta delta amount of token1 in swap
    function uniswapV3SwapCallback(
        int256 _amount0Delta,
        int256 _amount1Delta,
        bytes calldata
    ) external onlySwapPool {
        require(_amount0Delta > 0 || _amount1Delta > 0);

        if (_amount0Delta > 0) {
            IERC20Upgradeable(cache.token0.toAddress()).safeTransfer(cache.currentSwapPool, uint256(_amount0Delta));
            return;
        }
        IERC20Upgradeable(cache.token1.toAddress()).safeTransfer(cache.currentSwapPool, uint256(_amount1Delta));
    }

    function buy(
        uint256 _yourToken,
        uint256 _wantToken,
        uint256 _amount,
        uint24 _fee
    ) external override returns(int[] memory amounts){
        amounts = new int[](2);
        cache.currentSwapPool = factory.getPool(_yourToken.toAddress(), _wantToken.toAddress(), _fee);
        bool zeroForOne = (_yourToken.toAddress() == IUniswapV3Pool(cache.currentSwapPool).token0()) ? true : false;
        if (zeroForOne) {
            cache.token0 = _yourToken;
            cache.token1 = _wantToken;
        } else {
            cache.token0 = _wantToken;
            cache.token1 = _yourToken;
        }

        (amounts[0], amounts[1]) = IUniswapV3Pool(cache.currentSwapPool).swap(
            address(this),
            zeroForOne,
            int256(_amount) * (- 1),
            (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            new bytes(0)
        );
        cache.currentSwapPool = address(0);
        cache.token0 = 0;
        cache.token1 = 0;
    }

    function sell(
        uint _yourToken,
        uint _wantToken,
        uint _amount,
        uint24 _fee
    ) external override returns (int[] memory amounts){
        amounts = new int[](2);
        cache.currentSwapPool = factory.getPool(_yourToken.toAddress(), _wantToken.toAddress(), _fee);
        bool zeroForOne = (_yourToken.toAddress() == IUniswapV3Pool(cache.currentSwapPool).token0()) ? true : false;
        if (zeroForOne) {
            cache.token0 = _yourToken;
            cache.token1 = _wantToken;
        } else {
            cache.token0 = _wantToken;
            cache.token1 = _yourToken;
        }

        (amounts[0], amounts[1]) = IUniswapV3Pool(cache.currentSwapPool).swap(
            address(this),
            zeroForOne,
            int256(_amount),
            (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1),
            new bytes(0)
        );
        cache.currentSwapPool = address(0);
        cache.token0 = 0;
        cache.token1 = 0;
    }

    function mint(
        uint[] calldata _tokens,
        uint[] calldata _amounts,
        uint24 _fee,
        int24 _tickLower,
        int24 _tickUpper
    ) external override returns (uint tokenId){
        cache.currentSwapPool = factory.getPool(_tokens[0].toAddress(), _tokens[1].toAddress(), _fee);
        uint amount0;
        uint amount1;
        if (_tokens[0].toAddress() == IUniswapV3Pool(cache.currentSwapPool).token0()) {
            cache.token0 = _tokens[0];
            cache.token1 = _tokens[1];
            amount0 = _amounts[0];
            amount1 = _amounts[1];
        } else {
            cache.token0 = _tokens[1];
            cache.token1 = _tokens[0];
            amount0 = _amounts[1];
            amount1 = _amounts[0];
        }
        uint connectionId = occupyConnection();

        uint160 lowerSqrtRatioX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        uint160 upperSqrtRatioX96 = TickMath.getSqrtRatioAtTick(_tickUpper);

        (uint160 sqrtPriceX96, , , , , ,) = IUniswapV3Pool(cache.currentSwapPool).slot0();

        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            lowerSqrtRatioX96,
            upperSqrtRatioX96,
            amount0,
            amount1
        );

        IUniswapV3Pool(cache.currentSwapPool).mint(
            address(this),
            _tickLower,
            _tickUpper,
            liquidityDelta,
            new bytes(0)
        );
        tokenId = (wrapperTokenType << 232)
        + (uint256(uint24(_tickLower)) << 208)
        + (uint256(uint24(_tickUpper)) << 184)
        + (connectionId << 160)
        + uint256(uint160(currentSwapPool));

        asset.mint(msgSender(), tokenId, 1);
        cache.currentSwapPool = address(0);
        cache.token0 = 0;
        cache.token1 = 0;
        return tokenId;
    }

    /// @dev Burn uniswap v3 liquidity.
    /// @param _tokenId token id
    /// @param _liquidity liquidity to burn
    function burn(
        uint256 _tokenId,
        uint128 _liquidity
    ) external override {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 184);

        bytes memory callData = abi.encodeWithSignature(
            "burnLogic(uint256,uint128,address,address)", _tokenId, _liquidity, address(asset), address(this)
        );
        address connection = connectionPool.getConnectionAddress(connectionId);
        IConnection(connection).execute(address(this), callData);

        address pool = address(uint160(_tokenId));
        int24 tickLower = int24(uint24(_tokenId >> 208));
        int24 tickUpper = int24(uint24(_tokenId >> 184));

        bytes32 positionKey = PositionKey.compute(address(connection), tickLower, tickUpper);
        (uint128 remainingLiquidity, , , ,) = IUniswapV3Pool(pool).positions(positionKey);
        if (remainingLiquidity == 0) {
            asset.burn(msgSender(), _tokenId, 1);
            bytes memory callData = abi.encodeWithSignature(
                "harvestLogic(uint256,address)", _tokenId, address(this)
            );
            IConnection(connection).execute(address(this), callData);
            connectionBitMap.release(connectionId);
        }
    }

    function burnLogic(
        uint256 _tokenId,
        uint128 _liquidity,
        address _asset,
        address _caller
    ) external {
        address pool = address(uint160(_tokenId));
        int24 tickLower = int24(uint24(_tokenId >> 208));
        int24 tickUpper = int24(uint24(_tokenId >> 184));
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();
        IUniswapV3Pool(pool).burn(tickLower, tickUpper, _liquidity);
        IAsset(_asset).safeTransferFrom(_caller, _caller, token0, IERC20Upgradeable(token0).balanceOf(address(this)));
        IAsset(_asset).safeTransferFrom(_caller, _caller, token1, IERC20Upgradeable(token1).balanceOf(address(this)));
    }

    function harvest(
        uint256 _tokenId
    ) external {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 160);
        bytes memory callData = abi.encodeWithSignature(
            "harvestLogic(uint256,address)", _tokenId, msgSender()
        );
        address connection = connectionPool.getConnectionAddress(connectionId);
        IConnection(connection).execute(address(this), callData);
    }

    function harvestLogic(
        uint256 _tokenId,
        address _caller
    ) external {
        address pool = address(uint160(_tokenId));
        int24 tickLower = int24(uint24(_tokenId >> 208));
        int24 tickUpper = int24(uint24(_tokenId >> 184));
        // the actual amounts collected are returned
        IUniswapV3Pool(pool).collect(
            _caller,
            tickLower,
            tickUpper,
            type(uint128).max,
            type(uint128).max
        );
    }

    function occupyConnection() internal returns (uint){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax() / 256);
        connectionBitMap.occupy(connectionId);
        return connectionId;
    }
}
