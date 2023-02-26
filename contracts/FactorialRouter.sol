// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../interfaces/ITrigger.sol";
import "../interfaces/IWrapper.sol";
import "./Tokenization.sol";

/// It combine risk management + token box + router
contract FactorialRouter is Tokenization {
    /// @dev Call to the target using the given data.
    /// @param _maximumLoss The maximum loss slippage
    /// @param _data The data used in the call.
    function execute(uint96 _maximumLoss, address _target, bytes calldata _data) external {
        beforeExecute(_maximumLoss);
        executeInternal(_target, _data);
        afterExecute();
    }

    /// @dev Call batch to the target using the given data array.
    /// @param _maximumLoss The maximum loss slippage
    /// @param _targetArray The target array used in the call.
    /// @param _dataArray The data array used in the call.
    function executeBatch(uint256 _maximumLoss,  address[] calldata targetArray, bytes[] calldata _dataArray) external {
        beforeExecute(_maximumLoss);
        for (uint256 idx = 0; idx < _dataArray.length; idx ++) {
            executeInternal(targetArray[idx], _dataArray[idx]);
        }
        afterExecute();
    }

    /// @dev Internal function call to the target using the given data.
    /// @param _target The target contract address to call.
    /// @param _data The data used in the call.
    function executeInternal(address _target, bytes calldata _data) internal {
        (bool ok, bytes memory returndata) = _target.call(_data);
        if (!ok) {
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert('bad execute call');
            }
        }
    }

    function beforeExecute(uint _maximumLoss) internal {
        require(cache.caller != address(0), 'Locked');
        cache.caller = msg.sender;
        cache.maximumLoss = _maximumLoss;
    }

    function afterExecute() internal {
        require(cache.outputValue + cache.maximumLoss > cache.initialValue, 'Over slippage');
        cache.caller = address(0);
        cache.maximumLoss = 0;
        cache.inputValue = 0;
        cache.outputValue = 0;
    }
}
