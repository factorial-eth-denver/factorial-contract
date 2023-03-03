// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract TriggerLogicStopLoss is ITriggerLogic {

    Tokenization tokenization;

    constructor(address _tokenization) {
        tokenization = Tokenization(_tokenization);
    }

    struct StopLossParams {
        uint256 tokenId;
        uint256 tokenAmount;
        uint256 stopLoss;
    }

    function check(
        bytes calldata _stopLossParams
    ) external override view returns (bool) {
        StopLossParams memory params = abi.decode(
            _stopLossParams,
            (StopLossParams)
        );
        uint256 currentValue = tokenization.getValue(params.tokenId, params.tokenAmount);

        return currentValue <= params.stopLoss;
    }
}
