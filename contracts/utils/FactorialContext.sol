// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../interfaces/IAsset.sol";
import "../../interfaces/IFactorialModule.sol";

abstract contract FactorialContext is IFactorialModule{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// ----- INIT STATES -----
    address public router;
    IAsset public asset;

    /// @dev Initialize context.
    modifier initContext(address _asset) {
        asset = IAsset(_asset);
        router = asset.router();
        _;
    }

    function msgSender() internal view returns (address){
        if (msg.sender == router) {
            return asset.caller();
        }
        return msg.sender;
    }

    function doTransfer(address _token, address _to, uint256 _amount) external override {
        require(msg.sender == address(asset), 'Only asset');
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
    }
}
