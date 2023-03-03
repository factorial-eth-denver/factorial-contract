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

    uint public wrapperTokenType;

    /// @dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _tokenization,
        address _asset,
        address _connectionPool,
        address _masterChef,
        address _sushiRouter,
        uint _wrapperTokenType
    ) public initializer initContext(_asset) {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        connectionPool = IConnectionPool(_connectionPool);
        miniChef = IMiniChef(_masterChef);
        sushiRouter = IUniswapV2Router(_sushiRouter);
        sushi = IERC20Upgradeable(miniChef.SUSHI());
        wrapperTokenType = _wrapperTokenType;
    }

    function buy(uint _yourToken, uint _wantToken, uint _amount, uint24) external override returns (int[] memory amounts){
        // 0. Get lp address
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_yourToken.toAddress(), _wantToken.toAddress());

        // 1. Calculate amount in
        bool zeroToOne = false;
        uint amountIn;
        {
            uint reserveIn;
            uint reserveOut;
            if (IUniswapV2Pair(lp).token0() == _yourToken.toAddress()) {
                (reserveIn, reserveOut,) = IUniswapV2Pair(lp).getReserves();
                zeroToOne = true;
            } else {
                (reserveOut, reserveIn,) = IUniswapV2Pair(lp).getReserves();
            }
            uint numerator = reserveIn * _amount * 1000;
            uint denominator = (reserveOut - _amount) * 997;
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

    function sell(uint _yourToken, uint _wantToken, uint _amount, uint24) external override returns (int[] memory amounts){
        // 0. Get lp address
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_yourToken.toAddress(), _wantToken.toAddress());

        // 1. Calculate amount out
        bool zeroToOne = false;
        uint amountOut;
        {
            uint reserveIn;
            uint reserveOut;
            if (IUniswapV2Pair(lp).token0() == _yourToken.toAddress()) {
                (reserveIn, reserveOut,) = IUniswapV2Pair(lp).getReserves();
                zeroToOne = true;
            } else {
                (reserveOut, reserveIn,) = IUniswapV2Pair(lp).getReserves();
            }
            uint amountInWithFee = _amount * 997;
            uint numerator = amountInWithFee * reserveOut;
            uint denominator = (reserveIn * 1000) + amountInWithFee;
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

    function mint(uint[] calldata _tokens, uint[] calldata _amounts) external override returns (uint) {
        require(_tokens.length == 2 && _amounts.length == 2, 'Invalid params');
        asset.safeBatchTransferFrom(msgSender(), address(this), _tokens, _amounts, '');
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(miniChef), _amounts[0]);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(miniChef), _amounts[1]);
        (uint amountA, uint amountB, uint liquidity) = sushiRouter.addLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amounts[0], _amounts[1], 0, 0, address(this), block.timestamp
        );
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        asset.safeTransferFrom(address(this), msgSender(), lp, liquidity);
        if (amountA < _amounts[0]) asset.safeTransferFrom(address(this), msgSender(), _tokens[0], _amounts[0] - amountA, '');
        if (amountB < _amounts[1]) asset.safeTransferFrom(address(this), msgSender(), _tokens[1], _amounts[1] - amountB, '');
        // for gas refund
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(miniChef), 0);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(miniChef), 0);
        return liquidity;
    }

    function burn(uint[] calldata _tokens, uint _amount) external override returns (uint, uint) {
        require(_tokens.length == 2, 'Invalid params');
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        IERC20Upgradeable(lp).approve(address(miniChef), _amount);
        asset.safeTransferFrom(msgSender(), address(this), lp, _amount);
        (uint amountA, uint amountB) = sushiRouter.removeLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amount, 0, 0, address(this), block.timestamp
        );
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
        uint tokenId = (wrapperTokenType << 232) + (uint256(connectionId) << 80) + (_pid);
        asset.mint(msgSender(), tokenId, 1);
        return tokenId;
    }

    function depositExist(uint _tokenId, uint _amount) external override {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 80);
        uint pid = uint256(uint80(_tokenId));
        address connection = connectionPool.getConnectionAddress(connectionId);
        bytes memory callData = abi.encodeWithSignature(
            "deposit(uint256,uint256,address,address,address,address)",
            pid, _amount, address(asset), address(miniChef), address(sushi), msgSender()
        );
        IConnection(connection).execute(address(this), callData);
    }

    function deposit(uint _pid, uint _amount, address _asset, address _masterChef, address _sushi, address _caller) external {
        address lp = IMiniChef(_masterChef).lpToken(_pid);
        IAsset(_asset).safeTransferFrom(_caller, address(this), lp, _amount);
        IERC20Upgradeable(lp).approve(_masterChef, _amount);
        IMiniChef(_masterChef).deposit(_pid, _amount, address(this));
        IAsset(_asset).safeTransferFrom(
            address(this), _caller, _sushi, IERC20Upgradeable(_sushi).balanceOf(address(this))
        );
    }

    function withdraw(uint _tokenId, uint _amount) external override {
        require(asset.balanceOf(msgSender(), _tokenId) == 1, 'Not token owner');
        uint24 connectionId = uint24(_tokenId >> 80);
        uint pid = uint256(uint80(_tokenId));
        address connection = connectionPool.getConnectionAddress(connectionId);
        require(!connectionBitMap.isEmpty(connectionId), 'Empty connection');
        bytes memory callData = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address,address,address,address)",
            pid, _amount, address(asset), address(miniChef), address(sushi), msgSender()
        );
        IConnection(connection).execute(address(this), callData);
        (uint amount,) = miniChef.userInfo(pid, connection);
        if (amount == 0) {
            asset.burn(msgSender(), _tokenId, 1);
            connectionBitMap.release(connectionId);
        }
    }

    function withdraw(uint _pid, uint _amount, address _asset, address _masterChef, address _sushi, address _caller) external {
        address lp = IMiniChef(_masterChef).lpToken(_pid);
        IMiniChef(_masterChef).withdraw(_pid, _amount, address(this));
        IAsset(_asset).safeTransferFrom(
            address(this), _caller, _sushi, IERC20Upgradeable(_sushi).balanceOf(address(this))
        );
        IAsset(_asset).safeTransferFrom(address(this), _caller, lp, _amount);
    }

    function setPools(uint lp, uint pool) external onlyOwner {
        lpToPoolId[lp] = pool;
    }

    function getPoolId(uint _tokenA, uint _tokenB) external view returns (uint256) {
        return lpToPoolId[getLP(_tokenA, _tokenB)];
    }

    function getLP(uint _tokenA, uint _tokenB) public view returns (uint256) {
        return uint256(uint160(IUniswapV2Factory(sushiRouter.factory()).getPair(_tokenA.toAddress(), _tokenB.toAddress())));
    }

    function getNextTokenId(uint _pid) public view returns (uint256) {
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax() / 256);
        return (wrapperTokenType << 232) + (uint256(connectionId) << 80) + (_pid);
    }

    function occupyConnection() internal returns (uint24){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax() / 256);
        connectionBitMap.occupy(connectionId);
        return connectionId;
    }

    function getReserves(uint _tokenA, uint _tokenB) public returns (uint, uint){
        (uint112 reserveA, uint112 reserveB,) = IUniswapV2Pair(getLP(_tokenA, _tokenB).toAddress()).getReserves();
        return (uint256(reserveA), uint256(reserveB));
    }

    function optiamlSwapAmount(
        uint tokenA,
        uint tokenB,
        uint amountA,
        uint amountB
    ) external returns (uint swapAmt, bool isReversed) {
        (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB);
        return optimalDeposit(amountA, amountB, reserveA, reserveB);
    }

    function optimalDeposit(
        uint amtA,
        uint amtB,
        uint resA,
        uint resB
    ) internal pure returns (uint swapAmt, bool isReversed) {
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
        uint amtA,
        uint amtB,
        uint resA,
        uint resB
    ) internal pure returns (uint) {
        require(amtA * resB >= amtB * resA, 'Reversed');
        uint a = 997;
        uint b = uint(1997) * resA;
        uint _c = (amtA * resB) - (amtB * resA);
        uint c = (_c * 1000) / (amtB + resB) * resA;
        uint d = a * c * 4;
        uint e = Math.sqrt(b * b + d);
        uint numerator = e - b;
        uint denominator = a * 2;
        return numerator / denominator;
    }
}
