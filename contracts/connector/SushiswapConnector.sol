// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/external/IUniswapV2Factory.sol";
import "../../interfaces/external/IUniswapV2Router.sol";
import "../../interfaces/external/IMasterChef.sol";
import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/IAsset.sol";

import "./library/ConnectionBitmap.sol";
import "./library/SafeCastUint256.sol";

contract SushiswapConnector is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUint256 for uint;
    using ConnectionBitmap for mapping(uint24 => uint256);

    ITokenization public tokenization;
    IAsset public asset;
    IConnectionPool public connectionPool;
    IMasterChef public masterChef;
    IUniswapV2Router public sushiRouter;
    IERC20Upgradeable public sushi;

    mapping(uint24 => uint256) public connectionBitMap;

    uint public wrapperTokenType;

    function initialize(
        address _tokenization,
        address _asset,
        address _connectionPool,
        address _masterChef,
        address _sushi,
        uint _wrapperTokenType
    ) public initializer {
        tokenization = ITokenization(_tokenization);
        asset = IAsset(_asset);
        connectionPool = IConnectionPool(_connectionPool);
        masterChef = IMasterChef(masterChef);
        sushi = IERC20Upgradeable(_sushi);
        wrapperTokenType = _wrapperTokenType;
    }

    function buy(uint _yourToken, uint _wantToken, uint _amount) external {
        uint balance = asset.balanceOf(msg.sender, _yourToken);
        asset.safeTransferFrom(msg.sender, address(this), _yourToken, balance, '');
        address[] memory path = new address[](2);
        (path[0], path[1]) = (_yourToken.toAddress(), _wantToken.toAddress());
        sushiRouter.swapTokensForExactTokens(_amount, balance, path, address(this), block.timestamp);
        uint left = asset.balanceOf(address(this), _yourToken);
        asset.safeTransferFrom(address(this), msg.sender, _yourToken, left, '');
    }

    function sell(uint _yourToken, uint _wantToken, uint _amount) external {
        asset.safeTransferFrom(msg.sender, address(this), _yourToken, _amount, '');
        address[] memory path = new address[](2);
        (path[0], path[1]) = (_yourToken.toAddress(), _wantToken.toAddress());
        sushiRouter.swapExactTokensForTokens(_amount, 1, path, address(this), block.timestamp);
    }

    function mint(uint[] calldata _tokens, uint[] calldata _amounts) external returns (uint) {
        require(_tokens.length == 2 && _amounts.length == 2, 'Invalid params');
        asset.safeBatchTransferFrom(msg.sender, address(this), _tokens, _amounts, '');
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(masterChef), _amounts[0]);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(masterChef), _amounts[1]);
        (uint amountA, uint amountB, uint liquidity) = sushiRouter.addLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amounts[0], _amounts[1], 0, 0, address(this), block.timestamp
        );
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        asset.safeTransferFrom(address(this), msg.sender, lp, liquidity);
        if (amountA < _amounts[0]) asset.safeTransferFrom(address(this), msg.sender, _tokens[0], _amounts[0] - amountA, '');
        if (amountB < _amounts[1]) asset.safeTransferFrom(address(this), msg.sender, _tokens[1], _amounts[1] - amountB, '');
        // for gas refund
        IERC20Upgradeable(_tokens[0].toAddress()).approve(address(masterChef), 0);
        IERC20Upgradeable(_tokens[1].toAddress()).approve(address(masterChef), 0);
        return liquidity;
    }

    function burn(uint[] calldata _tokens, uint _amount) external returns (uint, uint) {
        require(_tokens.length == 2, 'Invalid params');
        address lp = IUniswapV2Factory(sushiRouter.factory()).getPair(_tokens[0].toAddress(), _tokens[1].toAddress());
        IERC20Upgradeable(lp).approve(address(masterChef), _amount);
        asset.safeTransferFrom(msg.sender, address(this), lp, _amount);
        (uint amountA, uint amountB) = sushiRouter.removeLiquidity(
            _tokens[0].toAddress(), _tokens[1].toAddress(), _amount, 0, 0, address(this), block.timestamp
        );
        asset.safeTransferFrom(address(this), msg.sender, _tokens[0], amountA, '');
        asset.safeTransferFrom(address(this), msg.sender, _tokens[1], amountB, '');
        return (amountA, amountB);
    }

    function deposit(uint _pid, uint _amount) external {
        uint connectionId = occupyConnection();
        address connection = connectionPool.getConnectionAddress(connectionId);
        bytes memory callData = abi.encodeWithSignature(
            "deposit(uint256,uint256,address,address)",
            _pid, _amount, masterChef, sushi
        );
        IConnection(connection).execute(address(this), callData);
        uint tokenId = (wrapperTokenType << 232) + (connectionId << 80) + (_pid);
        asset.mint(msg.sender, tokenId, 1);
    }

    function deposit(uint _pid, uint _amount, address _masterChef, address _sushi) external {
        (address lp, , ,) = IMasterChef(_masterChef).poolInfo(_pid);
        IAsset(asset).safeTransferFrom(msg.sender, address(this), lp, _amount);
        IERC20Upgradeable(lp).approve(_masterChef, _amount);
        IMasterChef(_masterChef).deposit(_pid, _amount);
        IAsset(asset).safeTransferFrom(
            address(this), msg.sender, _sushi, IERC20Upgradeable(_sushi).balanceOf(address(this))
        );

    }

    function withdraw(uint _tokenId, uint _amount) external {
        asset.burn(msg.sender, _tokenId, 1);
        uint24 connectionId = uint24(_tokenId >> 80);
        uint pid = uint256(uint80(_tokenId));
        address connection = connectionPool.getConnectionAddress(connectionId);
        require(!connectionBitMap.isEmpty(connectionId), 'Empty connection');
        bytes memory callData = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address,address,address)",
            pid, _amount, masterChef, sushi, msg.sender
        );
        IConnection(connection).execute(address(this), callData);
        (uint amount,) = masterChef.userInfo(pid, connection);
        if (amount == 0) connectionBitMap.release(connectionId);
    }

    function withdraw(uint _pid, uint _amount, address masterChef, address sushi, address caller) external {
        (address lp, , ,) = IMasterChef(masterChef).poolInfo(_pid);
        IMasterChef(masterChef).withdraw(_pid, _amount);
        IAsset(asset).safeTransferFrom(
            address(this), caller, uint256(uint160(sushi)), IERC20Upgradeable(sushi).balanceOf(address(this)), ''
        );
        IAsset(asset).safeTransferFrom(address(this), caller, uint256(uint160(lp)), _amount, '');
    }

    function occupyConnection() internal returns (uint){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax());
        connectionBitMap.occupy(connectionId);
        return connectionId;
    }
}
