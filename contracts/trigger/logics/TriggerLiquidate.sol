// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";
import "../../valuation/wrapper/DebtNFT.sol";

// Uncomment this line to use console.log
import "hardhat/console.sol";

contract TriggerLogicLiquidate is ITriggerLogic {

    Tokenization public  tokenization;
    DebtNFT public debtNFT;

    constructor(address _debtNFT) {
        debtNFT = DebtNFT(_debtNFT);
    }

    struct LiquidateParams {
        uint256 tokenId;
        uint256 tokenAmount;
        uint256 stopLoss;
        address lending;
    }

    function check(
        bytes calldata _liquidateParams
    ) external override view returns (bool) {
        LiquidateParams memory params = abi.decode(
            _liquidateParams,
            (LiquidateParams)
        );
        uint256 currentValue = debtNFT.getValueAsCollateral(params.lending, params.tokenId, params.tokenAmount);

        return currentValue <= params.stopLoss;
    }
}
