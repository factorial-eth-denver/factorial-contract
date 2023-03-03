// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "../../interfaces/external/IMasterChef.sol";

contract MockSushi is IMasterChef {
    address public sushi;
    address public lpToken;
    uint public amount;

    constructor(address _sushi, address _lpToken) {
        sushi = _sushi;
        lpToken = _lpToken;
    }

    /// Mock Router
    function swapTokensForExactTokens(
        uint _amountOut,
        uint,
        address[] calldata _path,
        address,
        uint
    ) external returns (uint[] memory amounts){
        IERC20(_path[0]).transferFrom(msg.sender, address(this), _amountOut);
        IERC20(_path[1]).transfer(msg.sender, _amountOut);
        amounts = new uint[](2);
        amounts[1] = _amountOut;
    }

    function swapExactTokensForTokens(
        uint _amountIn,
        uint,
        address[] calldata _path,
        address,
        uint
    ) external returns (uint[] memory amounts){
        IERC20(_path[0]).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_path[1]).transfer(msg.sender, _amountIn);
        amounts = new uint[](2);
        amounts[1] = _amountIn;
    }

    /// Mock Master Chef
    function poolInfo(uint pid) external view override returns (address, uint, uint, uint) {
        return (lpToken, 0, 0, 0);
    }

    function deposit(uint, uint _amount) external override {
        amount += _amount;
        IERC20(lpToken).transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint, uint _amount) external override {
        amount -= _amount;
        IERC20(lpToken).transfer(msg.sender, _amount);
    }

    function userInfo(uint pid, address user) external view returns (uint amount, uint rewardDebt) {
        return (amount, 0);
    }
}
