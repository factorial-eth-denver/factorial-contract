// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../valuation/Tokenization.sol";
import "../../../interfaces/ILiquidationModule.sol";
import "../../valuation/wrapper/DebtNFT.sol";
import "../../../interfaces/ILending.sol";
import "../Liquidation.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract LiquidationBasic is ILiquidationModule {
    Liquidation public liquidation;
    Tokenization public tokenization;
    DebtNFT public debtNFT;

    uint256 liquidateBonusRatio = 0.05e18;

    struct ExecuteParams {
        uint256 positionId;
        address prevOwner; // 이게문제가 안될까?
    }

    function execute(address liquidator, bytes calldata data) public {
        ExecuteParams memory params = abi.decode(data, (ExecuteParams));

        address[] memory inAccounts = new address[](1);
        uint256[] memory inAmounts = new uint256[](1);
        address[] memory outAccounts = new address[](2);
        uint256[] memory outAmounts = new uint256[](2);

        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(params.positionId);

        uint256 totalDebtValue;
        uint256 collateralValue;
        uint256 bonusValue;

        {
            address _liquidator = liquidator;
            ILending lending = ILending(address(uint160(params.positionId)));
            ILending.BorrowInfo memory borrowInfo = lending.getBorrowInfo(
                params.positionId
            );

            uint256 fee = lending.calcFee(params.positionId);
            uint256 totalDebt = borrowInfo.debtAmount + fee;
            inAccounts[0] = _liquidator;
            inAmounts[0] = totalDebt;
            totalDebtValue = tokenization.getValue(
                uint256(uint160(borrowInfo.debtAsset)),
                totalDebt
            );
            collateralValue = tokenization.getValue(
                collateralToken,
                collateralAmount
            );
            bonusValue = Math.mulDiv(
                collateralAmount,
                liquidateBonusRatio,
                1e18
            );
        }

        if (bonusValue + totalDebtValue >= collateralValue) {
            outAccounts[0] = liquidator;
            outAmounts[0] = collateralAmount;
        } else {
            uint256 _debtAmount = Math.mulDiv(
                collateralAmount,
                totalDebtValue,
                collateralValue
            );
            uint256 _bounusAmount = Math.mulDiv(
                _debtAmount,
                liquidateBonusRatio,
                1e18
            );
            outAccounts[0] = liquidator;
            outAccounts[1] = params.prevOwner;
            outAmounts[0] = _debtAmount + _bounusAmount;
            outAmounts[1] = collateralAmount - _debtAmount - _bounusAmount;
        }
        liquidation.liquidate(
            params.positionId,
            inAccounts,
            inAmounts,
            outAccounts,
            outAmounts
        );
    }
}
