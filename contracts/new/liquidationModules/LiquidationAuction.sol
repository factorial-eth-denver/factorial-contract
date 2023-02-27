// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../Tokenization.sol";
import "../../wrapper/DebtNFT.sol";
import "../Liquidation.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract LiquidationAuction is ILiquidationExecutor {
    Liquidation public liquidation;
    Tokenization public tokenization;
    DebtNFT public debtNFT;
    Auction[] public auctions;

    struct Auction {
        uint256 positionId;
        uint256 endTime;
        address bidder;
        address bidAmount;
        bool isEnd;
    }

    constructor(address _tokenization, address _debtNFT) {
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
    }

    function execute(uint256 positionId, uint256 endTime) public {
        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(positionId);

        auctions.push(Auction(positionId, endTime, address(0), 0, false));
    }

    function bid(uint256 positionId, uint256 amount) public {
        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(positionId);
        Auction storage auction = auctions[positionId];
        require(auction.bidAmount > amount, "TS");
        require(auction.endTime > block.timestamp, "AE");
        if (auction.bidder != address(0)) {
            // return
            tokenization.transfer(collateralToken, auction.bidAmount);
        }
        tokenization.transferFrom(msg.sender, collateralToken, amount);
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

        address[] inAccounts = new address[](1);
        uint256[] inAmounts = new uint256[](1);
        address[] outAccounts = new address[](2);
        uint256[] outAmounts = new uint256[](2);

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
