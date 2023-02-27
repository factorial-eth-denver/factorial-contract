// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../interfaces/ITriggerLogic.sol";
import "../../Tokenization.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TriggerLogicMaturity is ITriggerLogic {
    struct MaturityParams {
        uint256 maturity;
    }

    function check(
        uint256 initialValue,
        uint256 currentValue,
        bytes calldata _maturityParams
    ) external override returns (bool) {
        MaturityParams memory params = abi.decode(
            _maturityParams,
            (MaturityParams)
        );
        return block.timestamp >= params.maturity;
    }
}
