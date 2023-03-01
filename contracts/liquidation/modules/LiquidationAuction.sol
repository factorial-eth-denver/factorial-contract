// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../interfaces/ILiquidationModule.sol";
import "../../../interfaces/IAsset.sol";
import "../../../interfaces/ILending.sol";

import "../../valuation/Tokenization.sol";
import "../../valuation/wrapper/DebtNFT.sol";
import "../Liquidation.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract LiquidationAuction is ILiquidationModule {
    Liquidation public liquidation;
    Tokenization public tokenization;
    DebtNFT public debtNFT;
    Auction[] public auctions;
    IAsset public asset;

    struct Auction {
        uint256 positionId;
        uint256 endTime;
        uint256 bidAmount;
        address bidder;
        bool isEnd;
    }

    struct ExecuteParams {
        uint256 period;
    }

    constructor(address _liquidation, address _tokenization, address _debtNFT, address _asset) {
        liquidation = Liquidation(_liquidation);
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
        asset = IAsset(_asset);
    }

    function execute(address liquidator, uint256 positionId, bytes calldata data) public {
        ExecuteParams memory params = abi.decode(data, (ExecuteParams));
        // (
        //     uint256 collateralToken,
        //     uint256 collateralAmount,
        //     address liquidationModule
        // ) = debtNFT.tokenInfos(params.positionId);

        auctions.push(
            Auction(
                positionId,
                block.timestamp + params.period,
                0,
                address(0),
                false
            )
        );
    }

    function bid(uint256 positionId, uint256 amount) public {
        ILending lending = ILending(address(uint160(positionId)));
        ILending.BorrowInfo memory borrowInfo = lending.getBorrowInfo(
            positionId
        );

        Auction storage auction = auctions[positionId];
        require(auction.bidAmount > amount, "TS");
        require(auction.endTime > block.timestamp, "AE");
        if (auction.bidder != address(0)) {
            // return
            IERC20(borrowInfo.debtAsset).transfer(
                auction.bidder,
                auction.bidAmount
            );
        }
        IERC20(borrowInfo.debtAsset).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        auction.bidder = msg.sender;
        auction.bidAmount = amount;
    }

    function settle(uint256 positionId) public {
        Auction storage auction = auctions[positionId];
        require(auction.isEnd == false, "AE");
        require(auction.endTime < block.timestamp, "NE");
        require(auction.bidder != address(0), "NB");

        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(positionId);

        address[] memory inAccounts = new address[](1);
        uint256[] memory inAmounts = new uint256[](1);
        address[] memory outAccounts = new address[](1);
        uint256[] memory outAmounts = new uint256[](1);

        inAccounts[0] = address(this);
        inAmounts[0] = auction.bidAmount;
        outAccounts[0] = auction.bidder;
        outAmounts[0] = collateralAmount;

        liquidation.liquidate(
            positionId,
            inAccounts,
            inAmounts,
            outAccounts,
            outAmounts
        );
    }
}
