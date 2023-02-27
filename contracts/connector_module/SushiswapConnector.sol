// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/external/IMasterChef.sol";
import "../../interfaces/IConnection.sol";
import "../../interfaces/IConnectionPool.sol";

import "../library/ConnectionBitmap.sol";
import "../../interfaces/ITokenization.sol";
import "../../interfaces/IAsset.sol";

contract SushiswapConnector is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using ConnectionBitmap for mapping(uint24 => uint256);

    mapping(uint24 => uint256) public connectionBitMap;
    ITokenization public tokenization;
    IAsset public asset;
    IConnectionPool public connectionPool;
    IMasterChef public masterChef;
    IERC20Upgradeable public sushi;
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

    function deposit(uint _pid, uint _amount) external {
        address connection = occupyConnection();
        (address lp, , ,) = masterChef.poolInfo();
        asset.safeTransferFrom(msg.sender, connection, lp, _amount);
        bytes memory callData = abi.encodeWithSignature("deposit(uint256,uint256)", _pid, _amount);
        IConnection(connection).execute(address(masterChef), callData);
        sushi.safeTransfer(msg.sender, sushi.balanceOf(address(this)));
    }

    function withdraw(uint24 _connectionId, uint _pid, uint _amount) external {
        require(!connectionBitMap.isEmpty(_connectionId), 'Empty connection');
        address connection = connectionPool.getConnectionAddress(_connectionId);
        (address lp, , ,) = masterChef.poolInfo();
        bytes memory callData = abi.encodeWithSignature("withdraw(uint256,uint256)", _pid, _amount);
        IConnection(connection).execute(address(masterChef), callData);
        transferAll(connection, address(sushi), msg.sender, sushi.balanceOf(connection));
        transferAll(connection, lp, msg.sender, _amount);
        (uint amount,) = masterChef.userInfo(_pid, connection);
        if (amount == 0) connectionBitMap.release(_connectionId);
    }

    function occupyConnection() internal returns (address){
        uint24 connectionId = connectionBitMap.findFirstEmptySpace(connectionPool.getConnectionMax());
        connectionBitMap.occupy(connectionId);
        return connectionPool.getConnectionAddress(connectionId);
    }

    function transferAll(address _connection, address _token, address _to, uint _amount) internal {
        uint balance = IERC20Upgradeable(_token).balanceOf(_connection);
        tokenization.wrap(balance);
        bytes memory callData = abi.encodeWithSignature("transfer(address,uint256)", address(this), _amount);
        IConnection(_connection).execute(_token, callData);
    }
}
