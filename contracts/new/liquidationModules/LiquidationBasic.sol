// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Tokenization.sol";
import "../interfaces/ILiquidationExecutor.sol";
import "../../wrapper/DebtNFT.sol";
import "../interfaces/ILending.sol";
import "../Liquidation.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract LiquidationBasic is ILiquidationExecutor {
    Liquidation public liquidation;
    Tokenization public tokenization;
    DebtNFT public debtNFT;

    uint256 liquidateBonusRatio = 0.05e18;

    function execute(
        uint256 positionId,
        address liquidator,
        address prevOwner
    ) public {
        address[] inAccounts = new address[](1);
        uint256[] inAmounts = new uint256[](1);
        address[] outAccounts = new address[](2);
        uint256[] outAmounts = new uint256[](2);

        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(positionId);

        ILending lending = ILending(address(uint160(positionId)));
        ILending.BorrowInfo borrowInfo = lending.getBorrowInfo(positionId);
        uint256 fee = lending.calcFee(positionId);

        uint256 totalDebt = borrowInfo.debtAmount + fee;

        inAccounts[0] = liquidator;
        inAmounts[0] = totalDebt;

        uint256 totalDebtValue = tokenization.getValue(
            borrowInfo.debtAsset,
            totalDebt
        );
        uint256 collateralValue = tokenization.getValue(
            collateralToken,
            collateralAmount
        );
        uint256 bonusValue = Math.mulDiv(
            collateralAmount,
            liquidateBonusRatio,
            1e18
        );
        if (bonusValue + totalDebtValue >= collateralValue) {
            IERC20(collateralToken).transfer(liquidator, collateralAmount);
            outAccounts[0] = liquidator;
            outAccounts[1] = collateralAmount;
        } else {
            // 담보가치 대비 비교해서 적절한 비율로 분배
            // 추가할것: 기존 청산자 주소가 필요함. 나머지를 주려면.
            outAccounts[0] = liquidator;
            outAccounts[1] = prevOwner;
            outAmounts[0] = bonusValue + totalDebtValue;
            outAmounts[1] = totalDebtValue - bonusValue;
        }
        liquidation.liquidate(
            positionId,
            inAccounts,
            inAmounts,
            outAccounts,
            outAmounts
        );
    }
}
