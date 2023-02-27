// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ITriggerLogic.sol";
import "../../Tokenization.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TriggerLogicTakeProfit is ITriggerLogic {
    struct TakeProfitParams {
        uint256 takeProfit;
    }

    function check(
        uint256 initialValue,
        uint256 currentValue,
        bytes calldata _takeProfitParams
    ) external override returns (bool) {
        TakeProfitParams memory params = abi.decode(
            _takeProfitParams,
            (TakeProfitParams)
        );
        return currentValue >= params.takeProfit;
    }
}
