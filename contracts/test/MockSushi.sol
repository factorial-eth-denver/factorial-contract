// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "../../interfaces/external/IMiniChef.sol";

contract MockSushi is IMiniChef {
    address public SUSHI;
    address public mockLpToken;
    uint256 public amount;

    constructor(address _sushi, address _lpToken) {
        SUSHI = _sushi;
        mockLpToken = _lpToken;
    }

    /// Mock Router
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint,
        address[] calldata _path,
        address,
        uint
    ) external returns (uint256[] memory amounts){
        IERC20(_path[0]).transferFrom(msg.sender, address(this), _amountOut);
        IERC20(_path[1]).transfer(msg.sender, _amountOut);
        amounts = new uint256[](2);
        amounts[1] = _amountOut;
    }

    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint,
        address[] calldata _path,
        address,
        uint
    ) external returns (uint256[] memory amounts){
        IERC20(_path[0]).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_path[1]).transfer(msg.sender, _amountIn);
        amounts = new uint256[](2);
        amounts[1] = _amountIn;
    }

    /// Mock Master Chef
    function poolInfo(uint256 pid) external view override returns (uint, uint, uint) {
        return (0, 0, 0);
    }

    function lpToken(uint256 pid) external view override returns (address) {
        return mockLpToken;
    }

    function deposit(uint, uint256 _amount, address) external override {
        amount += _amount;
        IERC20(mockLpToken).transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint, uint256 _amount, address) external override {
        amount -= _amount;
        IERC20(mockLpToken).transfer(msg.sender, _amount);
    }

    function userInfo(uint256 pid, address user) external view returns (uint256 amount, uint256 rewardDebt) {
        return (amount, 0);
    }
}
