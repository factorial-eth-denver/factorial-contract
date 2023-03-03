// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../interfaces/ILiquidationModule.sol";
import "../../../interfaces/IAsset.sol";
import "../../../interfaces/ILending.sol";

import "../../utils/FactorialContext.sol";
import "../../valuation/Tokenization.sol";
import "../../valuation/wrapper/DebtNFT.sol";
import "../Liquidation.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract LiquidationAuction is ILiquidationModule, OwnableUpgradeable, FactorialContext, ERC1155HolderUpgradeable {
    Liquidation public liquidation;
    Tokenization public tokenization;
    DebtNFT public debtNFT;

    mapping(uint256 => Auction) public auctions;

    struct Auction {
        uint256 bidAmount;
        address bidder;
    }

    function initialize(address _liquidation, address _tokenization, address _debtNFT, address _asset) initializer initContext(_asset) public {
        liquidation = Liquidation(_liquidation);
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
    }

    function execute(address liquidator, uint256 positionId, bytes calldata data) public {
        Auction storage auction = auctions[positionId];
        require(auction.bidder != address(0), "No bidder");
        
        address[] memory inAccounts = new address[](1);
        uint256[] memory inAmounts = new uint256[](1);
        address[] memory outAccounts = new address[](1);
        uint256[] memory outAmounts = new uint256[](1);
        (, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(positionId);

        inAccounts[0] = address(this);
        inAmounts[0] = auction.bidAmount;
        outAccounts[0] = auction.bidder;
        outAmounts[0] = collateralAmount;

        liquidation.liquidate(positionId, inAccounts, inAmounts, outAccounts, outAmounts);
    }

    function bid(uint256 positionId, uint256 amount) public {
        Auction storage auction = auctions[positionId];
        require(auction.bidAmount < amount, "Bid amount is too low");

        ILending lending = ILending(address(uint160(positionId)));
        ILending.BorrowInfo memory borrowInfo = lending.getBorrowInfo(
            positionId
        );
        if (auction.bidder != address(0)) {
            asset.safeTransferFrom(
                address(this), 
                msgSender(), 
                uint256(uint160(borrowInfo.debtAsset)), 
                borrowInfo.debtAmount, 
                ""
            );
        }
        asset.safeTransferFrom(
            msgSender(), 
            address(this), 
            uint256(uint160(borrowInfo.debtAsset)), 
            amount, 
            ""
        );
        auction.bidder = msgSender();
        auction.bidAmount = amount;
    }
}
