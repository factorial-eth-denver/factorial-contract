// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "../../contracts/connector/SushiswapConnector.sol";
import "./Lending.sol";

contract SimpleBorrower is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    // UniConnector public uni;
    DebtNFT public debtNFT;
    Lending public lending;
    SushiswapConnector public sushi;

    BorrowCache public borrowCache;
    BorrowCache public repayCache;

    function initialize(
        address _asset,
        address _lending,
        address _debtNFT,
        address _sushi
    ) public initContext(_asset) {
        lending = Lending(_lending);
        debtNFT = DebtNFT(_debtNFT);
        sushi = SushiswapConnector(_sushi);
    }

    // 깊은게 아니라 단순 토큰0을 담보로 토큰1을 빌려서 페어를 넣는다.
    function borrow(
        address collateralAsset,
        address debtAsset,
        uint256 collateralAmount,
        uint256 debtAmount
    ) public {
        require(borrowCache.init == false, "already borrowed");
        console.log("SimpleBorrower - borrow");
        asset.safeTransferFrom(msgSender(), address(this), uint256(uint160(collateralAsset)), collateralAmount, "");
        borrowCache = BorrowCache(true, collateralAsset, collateralAmount, debtAsset, debtAmount);
        uint256 id = lending.borrowAndCallback(uint256(uint160(debtAsset)), debtAsset, debtAmount);
        console.log("borrowId", id);
        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");
    }

    function nextId() public returns (uint256) {
        return 1;
    }

    function borrowCallback()
        public
        override
    {
        require(borrowCache.init == true, "not borrowed");
        uint256 tokenId = uint256(uint160(borrowCache.collateralAsset));
        uint256 tokenAmount = borrowCache.collateralAmount + borrowCache.debtAmount;
        asset.safeTransferFrom(address(this), msgSender(), tokenId, tokenAmount, "");
        console.log("Borrower");
        console.log("tokenId", tokenId);
        console.log("tokenAmount", tokenAmount);

        borrowCache.init = false;
    }

    // 포지션을 뭘로받을지 정해야한다.
    function repay(uint256 debtId) public {
        require(repayCache.init == false, "already repaid");

        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(debtId);
        (address debtAsset, uint256 debtAmount) = lending.getDebt(debtId);

        repayCache = BorrowCache(
            true,
            debtAsset,
            debtAmount,
            address(uint160(collateralToken)),
            collateralAmount
        );
        lending.repayAndCallback(debtId);
    }

    function repayCallback()
        public
        override
        returns (uint256 tokenId, uint256 tokenAmount)
    {
        require(repayCache.init == true, "not repaid");

        tokenId = uint256(uint160(repayCache.debtAsset));
        tokenAmount = repayCache.debtAmount;

        repayCache.init = false;
    }
}
