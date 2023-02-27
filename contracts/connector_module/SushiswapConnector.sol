// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/external/IUniswapV2Router.sol";
import "../../interfaces/external/IMasterChef.sol";
import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/IAsset.sol";

import "./library/ConnectionBitmap.sol";

contract SushiswapConnector is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
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
        (path[0], path[1]) = (_yourToken, _wantToken);
        sushiRouter.swapTokensForExactTokens(_amount, balance, path, address(this), block.timestamp);
        uint left = asset.balanceOf(address(this), _yourToken);
        asset.safeTransferFrom(address(this), msg.sender, _yourToken, left, '');
    }

    function sell(uint _yourToken, uint _wantToken, uint _amount) external {
        asset.safeTransferFrom(msg.sender, address(this), _yourToken, _amount, '');
        address[] memory path = new address[](2);
        (path[0], path[1]) = (_yourToken, _wantToken);
        sushiRouter.swapExactTokensForTokens(_amount, 1, path, address(this), block.timestamp);
    }

    function mint(uint[] calldata _tokens, uint[] calldata _amounts) external returns (uint) {
        require(_tokens.length == 2 && _amounts.length == 2, 'Invalid params');
        asset.safeBatchTransferFrom(msg.sender, address(this), _tokens, _amounts, '');
        sushiRouter.addLiquidity(_tokens[0], _tokens[1], _amounts[0], _amounts[1], address(this), block.timestamp);
        return 0;
    }

    function burn(uint yourToken, uint wantToken, uint amount) external returns (uint) {
        asset.safeTransferFrom(msg.sender, address(this), yourToken, amount, '');
        address[] memory path = new address[](2);
        (path[0], path[1]) = (yourToken, wantToken);
        sushiRouter.swapExactTokensForTokens(amount, 1, path, address(this), block.timestamp);
        return 0;
    }

    function deposit(uint _pid, uint _amount) external {
        address connection = occupyConnection();
        bytes memory callData = abi.encodeWithSignature(
            "deposit(uint256,uint256,address,address)",
            _pid, _amount, masterChef, sushi
        );
        IConnection(connection).execute(address(this), callData);
    }

    function deposit(uint _pid, uint _amount, address _masterChef, address _sushi) {
        (address lp, , ,) = IMasterChef(_masterChef).poolInfo();
        asset.safeTransferFrom(address(asset), address(this), lp, _amount, '');
        IERC20Upgradeable(lp).approve(_masterChef, max);
        IMasterChef(_masterChef).deposit(_pid, _amount);
        asset.safeTransferFrom(address(this), msg.sender, uint256(uint160(_sushi)), _sushi.balanceOf(address(this)));
    }

    function withdraw(uint _pid, uint _amount) external {
        require(!connectionBitMap.isEmpty(_connectionId), 'Empty connection');
        bytes memory callData = abi.encodeWithSignature(
            "withdraw(uint256,uint256,address,address,address)",
            _pid, _amount, masterChef, sushi, msg.sender
        );
        IConnection.execute(address(this), callData);
        (uint amount,) = masterChef.userInfo(_pid, connection);
        if (amount == 0) connectionBitMap.release(_connectionId);
    }

    function withdraw(uint _pid, uint _amount, address masterChef, address sushi, address caller) external {
        (address lp, , ,) = masterChef.poolInfo();
        IMasterChef(masterChef).withdraw(_pid, _amount);
        asset.safeTransferFrom(address(this), caller, uint256(uint160(sushi)), sushi.balanceOf(address(this)), '');
        asset.safeTransferFrom(address(this), caller, uint256(uint160(lp)), _amount, '');
    }

    function occupyConnection() internal returns (address){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax());
        connectionBitMap.occupy(connectionId);
        return connectionPool.getConnectionAddress(connectionId);
    }
}
