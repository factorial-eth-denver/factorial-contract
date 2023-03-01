// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../valuation/Tokenization.sol";
import "../valuation/wrapper/DebtNFT.sol";
import "../../interfaces/ILiquidationModule.sol";
import "../../interfaces/ILending.sol";
import "../../interfaces/IAsset.sol";

contract Liquidation {
    Tokenization public tokenization;
    DebtNFT public debtNFT;
    address public trigger;
    IAsset public asset;

    mapping(address => ILiquidationModule) public modules;

    constructor(
        address _tokenization,
        address _debtNFT,
        address _trigger,
        address _factorialAsset
    ) {
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
        trigger = _trigger;
        asset = IAsset(_factorialAsset);
    }

    function execute(
        address liquidationModule,
        uint256 tokenId,
        bytes calldata data
    ) public onlyTrigger {
        require(
            address(modules[liquidationModule]) != address(0),
            "Not registered"
        );
        //  = tokenization.ownerOf(positionId);
        // 만들어야 할것 Take Dept Position
        // tokenization.safeTransferFrom(
        //     msg.sender,
        //     address(this),
        //     tokenId,
        //     1,
        //     ""
        // );

        ILiquidationModule module = modules[liquidationModule];
        address liquidator = asset.caller();
        module.execute(liquidator, tokenId, data); //[수정]

        // ILending lending = ILending(address(uint160(positionId)));
        // deptNFT.transferFrom(liquidator, address(this), positionId);
    }

    function liquidate(
        uint256 positionId,
        address[] calldata inAccounts,
        uint256[] calldata inAmounts,
        address[] calldata outAccounts,
        uint256[] calldata outAmounts
    ) public onlyLiquidationModule {
        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(positionId);

        ILending lending = ILending(address(uint160(positionId)));
        ILending.BorrowInfo memory borrowInfo = lending.getBorrowInfo(
            positionId
        );
        for (uint256 i = 0; i < inAccounts.length; i++) {
            asset.safeTransferFrom(
                inAccounts[i],
                address(this),
                uint256(uint160(borrowInfo.debtAsset)),
                inAmounts[i],
                ""
            );
        }

        lending.liquidate(positionId);

        for (uint256 i = 0; i < outAccounts.length; i++) {
            asset.safeTransferFrom(
                address(this),
                outAccounts[i],
                collateralToken,
                outAmounts[i],
                ""
            );
        }
    }

    modifier onlyTrigger() {
        require(msg.sender == trigger, "Not trigger");
        _;
    }

    modifier onlyLiquidationModule() {
        require(address(modules[msg.sender]) != address(0), "Not registered");
        _;
    }
}
