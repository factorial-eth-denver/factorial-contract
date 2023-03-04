// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../interfaces/external/IUniswapV2Factory.sol";
import "../../../interfaces/external/IUniswapV2Router.sol";
import "../../../interfaces/external/IUniswapV2Pair.sol";
import "../../../interfaces/external/IMiniChef.sol";
import "../../../interfaces/IConnection.sol";
import "../../../interfaces/IConnectionPool.sol";
import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IAsset.sol";
import "../../../interfaces/IDexConnector.sol";
import "../../../interfaces/ISwapConnector.sol";

import "../library/ConnectionBitmap.sol";
import "../library/SafeCastUint256.sol";
import "../library/Math.sol";
import "../../utils/FactorialContext.sol";

contract SushiswapConnector is IDexConnector, ISwapConnector, OwnableUpgradeable, UUPSUpgradeable, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUint256 for uint;
    using ConnectionBitmap for mapping(uint24 => uint256);
    using Math for uint256;

    ITokenization public tokenization;
    IConnectionPool public connectionPool;
    IMiniChef public miniChef;
    IUniswapV2Router public sushiRouter;
    IERC20Upgradeable public sushi;

    mapping(uint24 => uint256) public connectionBitMap;
    mapping(uint256 => uint256) public lpToPoolId;

    uint256 public wrapperTokenType;

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _tokenization,
        address _asset,
        address _connectionPool,
        address _masterChef,
        address _sushiRouter,
        uint256 _wrapperTokenType
    ) public initializer initContext(_asset) {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        connectionPool = IConnectionPool(_connectionPool);
        miniChef = IMiniChef(_masterChef);
        sushiRouter = IUniswapV2Router(_sushiRouter);
        sushi = IERC20Upgradeable(miniChef.SUSHI());
        wrapperTokenType = _wrapperTokenType;
    }

    function buy(uint256 _yourToken, uint256 _wantToken, uint256 _amount, uint24) external override returns (int[] memory amounts){
        // 0. Get lp address
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_yourToken.toAddress(), _wantToken.toAddress());

        // 1. Calculate amount in
        bool zeroToOne = false;
        uint256 amountIn;
        {
            uint256 reserveIn;
            uint256 reserveOut;
            if (IUniswapV2Pair(lp).token0() == _yourToken.toAddress()) {
                (reserveIn, reserveOut,) = IUniswapV2Pair(lp).getReserves();
                zeroToOne = true;
            } else {
                (reserveOut, reserveIn,) = IUniswapV2Pair(lp).getReserves();
            }
            uint256 numerator = reserveIn * _amount * 1000;
            uint256 denominator = (reserveOut - _amount) * 997;
            amountIn = (numerator / denominator) + 1;
        }

        // 2. Swap
        asset.safeTransferFrom(msgSender(), address(this), _yourToken, amountIn, '');
        IERC20Upgradeable(_yourToken.toAddress()).transfer(lp, amountIn);
        if (zeroToOne) {
            IUniswapV2Pair(lp).swap(0, _amount, address(this), "");
        } else {
            IUniswapV2Pair(lp).swap(_amount, 0, address(this), "");
        }

        // Make return data
        amounts = new int[](2);
        amounts[0] = int256(amountIn) * - 1;
        amounts[1] = int256(_amount);
        asset.safeTransferFrom(address(this), msgSender(), _wantToken, _amount, '');
    }

    function sell(uint256 _yourToken, uint256 _wantToken, uint256 _amount, uint24) external override returns (int[] memory amounts){
        // 0. Get lp address
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_yourToken.toAddress(), _wantToken.toAddress());

        // 1. Calculate amount out
        bool zeroToOne = false;
        uint256 amountOut;
        {
            uint256 reserveIn;
            uint256 reserveOut;
            if (IUniswapV2Pair(lp).token0() == _yourToken.toAddress()) {
                (reserveIn, reserveOut,) = IUniswapV2Pair(lp).getReserves();
                zeroToOne = true;
            } else {
                (reserveOut, reserveIn,) = IUniswapV2Pair(lp).getReserves();
            }
            uint256 amountInWithFee = _amount * 997;
            uint256 numerator = amountInWithFee * reserveOut;
            uint256 denominator = (reserveIn * 1000) + amountInWithFee;
            amountOut = numerator / denominator;
        }

        // 2. Swap
        asset.safeTransferFrom(msgSender(), address(this), _yourToken, _amount, '');
        IERC20Upgradeable(_yourToken.toAddress()).transfer(lp, _amount);
        if (zeroToOne) {
            IUniswapV2Pair(lp).swap(0, amountOut, address(this), "");
        } else {
            IUniswapV2Pair(lp).swap(amountOut, 0, address(this), "");
        }

        // 3. Make return data
        amounts = new int[](2);
        amounts[0] = int256(_amount) * - 1;
        amounts[1] = int256(amountOut);
        asset.safeTransferFrom(address(this), msgSender(), _wantToken, amountOut, '');
    }

    function mint(uint256[] calldata _tokens, uint256[] calldata _amounts) external override returns (uint) {
        // 0. Validate params
        require(_tokens.length == 2 && _amounts.length == 2, 'Invalid params');

        // 1. Before mint
        asset.safeBatchTransferFrom(msgSender(), address(this), _tokens, _amounts, '');
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(sushiRouter), _amounts[0]);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(sushiRouter), _amounts[1]);

        // 2. Do mint
        (uint256 amountA, uint256 amountB, uint256 liquidity) = sushiRouter.addLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amounts[0], _amounts[1], 0, 0, address(this), block.timestamp
        );

        // 3. After mint
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        asset.safeTransferFrom(address(this), msgSender(), lp, liquidity);
        if (amountA < _amounts[0]) asset.safeTransferFrom(address(this), msgSender(), _tokens[0], _amounts[0] - amountA, '');
        if (amountB < _amounts[1]) asset.safeTransferFrom(address(this), msgSender(), _tokens[1], _amounts[1] - amountB, '');

        // 4. Reset approval
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(sushiRouter), 0);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(sushiRouter), 0);
        return liquidity;
    }

    function burn(uint256[] calldata _tokens, uint256 _amount) external override returns (uint, uint) {
        // 0. Validate params
        require(_tokens.length == 2, 'Invalid params');

        // 1. Before mint
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        IERC20Upgradeable(lp).approve(address(sushiRouter), _amount);
        asset.safeTransferFrom(msgSender(), address(this), lp, _amount);

        // 2. Do mint
        (uint256 amountA, uint256 amountB) = sushiRouter.removeLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amount, 0, 0, address(this), block.timestamp
        );

        // 3. After mint
        asset.safeTransferFrom(address(this), msgSender(), _tokens[0], amountA, '');
        asset.safeTransferFrom(address(this), msgSender(), _tokens[1], amountB, '');
        return (amountA, amountB);
    }

    function depositNew(uint256 _pid, uint256 _amount) external override returns (uint){
        uint24 connectionId = occupyConnection();
        address connection = connectionPool.getConnectionAddress(connectionId);
        bytes memory callData = abi.encodeWithSignature(
            "deposit(uint256,uint256,address,address,address,address)",
            _pid, _amount, address(asset), address(miniChef), address(sushi), msgSender()
        );
        IConnection(connection).execute(address(this), callData);
        uint256 tokenId = (wrapperTokenType << 232) + (uint256(connectionId) << 80) + (_pid);
        asset.mint(msgSender(), tokenId, 1);
        return tokenId;
    }

    function depositExist(uint256 _tokenId, uint256 _amount) external override {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 80);
        uint256 pid = uint256(uint80(_tokenId));
        address connection = connectionPool.getConnectionAddress(connectionId);
        bytes memory callData = abi.encodeWithSignature(
            "deposit(uint256,uint256,address,address,address,address)",
            pid, _amount, address(asset), address(miniChef), address(sushi), msgSender()
        );
        IConnection(connection).execute(address(this), callData);
    }

    function deposit(uint256 _pid, uint256 _amount, address _asset, address _masterChef, address _sushi, address _caller) external {
        address lp = IMiniChef(_masterChef).lpToken(_pid);
        IAsset(_asset).safeTransferFrom(_caller, address(this), lp, _amount);
        IERC20Upgradeable(lp).approve(_masterChef, _amount);
        IMiniChef(_masterChef).deposit(_pid, _amount, address(this));
        IAsset(_asset).safeTransferFrom(
            address(this), _caller, _sushi, IERC20Upgradeable(_sushi).balanceOf(address(this))
        );
    }

    function withdraw(uint256 _tokenId, uint256 _amount) external override {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 80);
        uint256 pid = uint256(uint80(_tokenId));
        address connection = connectionPool.getConnectionAddress(connectionId);
        require(!connectionBitMap.isEmpty(connectionId), 'Empty connection');
        bytes memory callData = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address,address,address,address)",
            pid, _amount, address(asset), address(miniChef), address(sushi), msgSender()
        );
        IConnection(connection).execute(address(this), callData);
        (uint256 amount,) = miniChef.userInfo(pid, connection);
        if (amount == 0) {
            asset.burn(msgSender(), _tokenId, 1);
            connectionBitMap.release(connectionId);
        }
    }

    function withdraw(uint256 _pid, uint256 _amount, address _asset, address _masterChef, address _sushi, address _caller) external {
        address lp = IMiniChef(_masterChef).lpToken(_pid);
        IMiniChef(_masterChef).withdraw(_pid, _amount, address(this));
        IAsset(_asset).safeTransferFrom(
            address(this), _caller, _sushi, IERC20Upgradeable(_sushi).balanceOf(address(this))
        );
        IAsset(_asset).safeTransferFrom(address(this), _caller, lp, _amount);
    }

    function setPools(uint256 lp, uint256 pool) external onlyOwner {
        lpToPoolId[lp] = pool;
    }

    function getPoolId(uint256 _tokenA, uint256 _tokenB) external view override returns (uint256) {
        return lpToPoolId[getLP(_tokenA, _tokenB)];
    }

    function getLP(uint256 _tokenA, uint256 _tokenB) public view override returns (uint256) {
        return uint256(uint160(IUniswapV2Factory(sushiRouter.factory()).getPair(_tokenA.toAddress(), _tokenB.toAddress())));
    }

    function getUnderlyingLp(uint256 _tokenId) external view override returns (uint256) {
        uint256 pid = uint256(uint80(_tokenId));
        address lp = miniChef.lpToken(pid);
        return uint256(uint160(lp));
    }

    function getUnderlyingAssets(uint256 _lp) external view override returns (uint256, uint256) {
        address token0 = IUniswapV2Pair(_lp.toAddress()).token0();
        address token1 = IUniswapV2Pair(_lp.toAddress()).token1();
        return (uint256(uint160(token0)), uint256(uint160(token1)));
    }

    function getNextTokenId(uint256 _pid) public view override returns (uint256) {
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax() / 256);
        return (wrapperTokenType << 232) + (uint256(connectionId) << 80) + (_pid);
    }

    function getReserves(uint256 _tokenA, uint256 _tokenB) public view override returns (uint, uint){
        address lp = getLP(_tokenA, _tokenB).toAddress();
        (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(lp).getReserves();
        if (IUniswapV2Pair(lp).token0() == _tokenA.toAddress()) {
            return (uint256(reserveA), uint256(reserveB));
        }
        return (uint256(reserveB), uint256(reserveA));
    }

    function optimalSwapAmount(
        uint256 tokenA,
        uint256 tokenB,
        uint256 amountA,
        uint256 amountB
    ) external override returns (uint256 swapAmt, bool isReversed) {
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
        return optimalDeposit(amountA, amountB, reserveA, reserveB);
    }

    function optimalDeposit(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB
    ) internal pure returns (uint256 swapAmt, bool isReversed) {
        if (amtA * resB >= amtB * resA) {
            swapAmt = _optimalDepositA(amtA, amtB, resA, resB);
            isReversed = false;
        } else {
            swapAmt = _optimalDepositA(amtB, amtA, resB, resA);
            isReversed = true;
        }
    }

    /// Formula: https://blog.alphafinance.io/byot/
    function _optimalDepositA(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB
    ) internal pure returns (uint) {
        require(amtA * resB >= amtB * resA, 'Reversed');
        uint256 a = 997;
        uint256 b = uint(1997) * resA;
        uint256 _c = (amtA * resB) - (amtB * resA);
        uint256 c = (_c * 1000) / (amtB + resB) * resA;
        uint256 d = a * c * 4;
        uint256 e = Math.sqrt(b * b + d);
        uint256 numerator = e - b;
        uint256 denominator = a * 2;
        return numerator / denominator;
    }

    function occupyConnection() internal returns (uint24){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax() / 256);
        connectionBitMap.occupy(connectionId);
        return connectionId;
    }
}
