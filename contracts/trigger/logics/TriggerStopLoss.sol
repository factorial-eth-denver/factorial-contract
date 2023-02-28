// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TriggerLogicStopLoss is ITriggerLogic {
    struct StopLossParams {
        uint256 stopLoss;
    }

    function check(
        uint256 initialValue,
        uint256 currentValue,
        bytes calldata _stopLossParams
    ) external override returns (bool) {
        StopLossParams memory params = abi.decode(
            _stopLossParams,
            (StopLossParams)
        );
        return currentValue <= params.stopLoss;
    }
}
