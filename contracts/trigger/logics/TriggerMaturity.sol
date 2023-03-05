// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";

contract TriggerLogicMaturity is ITriggerLogic {
    struct MaturityParams {
        uint256 maturity;
    }

    function check(
        bytes calldata _maturityParams
    ) external override view returns (bool) {
        MaturityParams memory params = abi.decode(
            _maturityParams,
            (MaturityParams)
        );
        return block.timestamp >= params.maturity;
    }
}
