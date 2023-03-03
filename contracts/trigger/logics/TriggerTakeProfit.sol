// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TriggerLogicTakeProfit is ITriggerLogic {

    Tokenization tokenization;

    constructor(address _tokenization) {
        tokenization = Tokenization(_tokenization);
    }

    struct TakeProfitParams {
        uint256 tokenId;
        uint256 tokenAmount;
        uint256 takeProfit;
    }

    function check(
        bytes calldata _takeProfitParams
    ) external override view returns (bool) {
        TakeProfitParams memory params = abi.decode(
            _takeProfitParams,
            (TakeProfitParams)
        );
        uint256 currentValue = tokenization.getValue(params.tokenId, params.tokenAmount);
        return currentValue >= params.takeProfit;
    }
}
