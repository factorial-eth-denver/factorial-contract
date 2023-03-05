// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../../interfaces/ITriggerLogic.sol";
import "../../valuation/Tokenization.sol";
import "../../valuation/wrapper/DebtNFT.sol";

contract TriggerLogicLiquidate is ITriggerLogic {

    Tokenization public  tokenization;
    DebtNFT public debtNFT;

    constructor(address _debtNFT) {
        debtNFT = DebtNFT(_debtNFT);
    }


    function check(
        bytes calldata _liquidateParams
    ) external override view returns (bool) {
        (uint256 tokenId, uint256 tokenAmount, uint256 stopLoss, address lending) = abi.decode(
            _liquidateParams,
            (uint256, uint256, uint256, address)
        );

        uint256 valueWithFactor = debtNFT.getValueWithFactor(lending, tokenId, tokenAmount);
        return valueWithFactor == 0;
    }
}
