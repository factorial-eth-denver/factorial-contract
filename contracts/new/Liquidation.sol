// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../Tokenization.sol";
import "../wrapper/DebtNFT.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Liquidation {
    Tokenization public tokenization;
    Trigger public trigger;
    DebtNFT public debtNFT;

    mapping(address => ILiquidationModule) public modules;

    constructor(address _tokenization, address _debtNFT, address _trigger) {
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
        trigger = Trigger(_trigger);
    }

    function execute(
        uint256 positionId,
        address liquidationModule,
        address liquidator
    ) public onlyTrigger {
        require(strategies[liquidationModule] != address(0), "Not registered");
        address prevOwner = tokenization.ownerOf(positionId);

        // 만들어야 할것 Take Dept Position
        ILiquidationModule module = modules[liquidationModule];
        module.execute(positionId, liquidator, prevOwner);

        ILending lending = ILending(address(uint160(positionId)));
        deptNFT.transferFrom(liquidator, address(this), positionId);
    }

    function liquidate(
        uint256 positionId,
        address[] inAccounts,
        uint256[] inAmounts,
        address[] outAccounts,
        uint256[] outAmounts
    ) public onlyLiquidationModule {
        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(positionId);

        ILending lending = ILending(address(uint160(positionId)));
        ILending.BorrowInfo borrowInfo = lending.getBorrowInfo(positionId);

        for (uint256 i = 0; i < inAccounts.length; i++) {
            IERC20(borrowInfo.debtAsset).transferFrom(
                inAccounts[i],
                address(this),
                inAmounts[i]
            );
        }
        lending.liquidate(positionId);

        for (uint256 i = 0; i < outAccounts.length; i++) {
            IERC20(collateralToken).transferFrom(
                outAccounts[i],
                address(this),
                outAmounts[i]
            );
        }
    }

    modifier onlyTrigger() {
        require(msg.sender == address(trigger), "Not trigger");
        _;
    }

    modifier onlyLiquidationModule() {
        require(modules[msg.sender] != address(0), "Not registered");
        _;
    }
}
