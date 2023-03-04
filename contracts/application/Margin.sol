// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../connector/sushi/SushiswapConnector.sol";
import "../valuation/Tokenization.sol";
import "../../interfaces/ILending.sol";
import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/SyntheticNFT.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";

contract Margin is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    DebtNFT public debtNFT;
    ILending public lending;
    SushiswapConnector public sushi;

    BorrowCache public borrowCache;
    BorrowCache public repayCache;

    struct BorrowCache {
        bool init;
        uint256 collateralAsset;
        uint256 collateralAmount;
        uint256 debtAsset;
        uint256 debtAmount;
    }

    function initialize(
        address _asset,
        address _lending,
        address _deptNFT,
        address _sushi
    ) public initContext(_asset) {
        lending = ILending(_lending);
        debtNFT = DebtNFT(_deptNFT);
        sushi = SushiswapConnector(_sushi);
    }

    // 깊은게 아니라 단순 토큰0을 담보로 토큰1을 빌려서 페어를 넣는다.
    function open(
        address collateralAsset,
        uint256 collateralAmount,
        address debtAsset,
        uint256 debtAmount
    ) public {
        console.log("open1");
        require(borrowCache.init == false, "already borrowed");
        console.log("open2");
        borrowCache = BorrowCache(true, uint256(uint160(collateralAsset)), collateralAmount, uint256(uint160(debtAsset)), debtAmount);
console.log("open3");
        asset.safeTransferFrom(msgSender(), address(this), uint256(uint160(collateralAsset)), collateralAmount, "");
        console.log("open4");
        uint256 id = lending.borrowAndCallback(uint256(uint160(collateralAsset)), debtAsset, debtAmount);
console.log("open5");
        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");
console.log("open6");
        delete borrowCache;
    }

    function borrowCallback() public override {
        require(borrowCache.init == true, "not borrowed");
        console.log("two1");
        console.log("borrowCache.debtAsset", borrowCache.debtAsset);
        console.log("borrowCache.collateralAsset", borrowCache.collateralAsset);
        console.log("borrowCache.debtAmount", borrowCache.debtAmount);
        console.log("borrowCache.collateralAmount", borrowCache.collateralAmount);
        console.log(asset.balanceOf(address(this), borrowCache.debtAsset));
        console.log(asset.balanceOf(address(this), borrowCache.collateralAsset));
        int256[] memory amounts = sushi.sell(borrowCache.debtAsset, borrowCache.collateralAsset, borrowCache.debtAmount, 0);
        console.log("two2");
        uint256 tokenAmount = borrowCache.collateralAmount + uint256(amounts[1]);
        console.log("two3");
        asset.safeTransferFrom(address(this), msg.sender, borrowCache.collateralAsset, tokenAmount, "");
    }

    // 포지션을 뭘로받을지 정해야한다.
    function close(uint256 debtId) public {
        require(repayCache.init == false, "already repaid");
        repayCache.init = true;
        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(debtId);
        (uint256 debtAsset, uint256 debtAmount) = lending.getDebt(debtId);
        repayCache = BorrowCache(true, collateralToken, collateralAmount, debtAsset, debtAmount);
        asset.safeTransferFrom(msgSender(), address(lending), debtId, 1, "");
        lending.repayAndCallback(debtId);
        repayCache.init = false;
    }

    function repayCallback() public override {
        require(repayCache.init == true, "not repaid");
        uint256 beforeBalance = asset.balanceOf(address(this), repayCache.collateralAsset);
        sushi.buy(repayCache.collateralAsset, repayCache.debtAsset, repayCache.debtAmount, 0);
        uint256 afterBalance = beforeBalance - asset.balanceOf(address(this), repayCache.collateralAsset);
        uint256 returnAmount = repayCache.collateralAmount - (beforeBalance - afterBalance);
        asset.safeTransferFrom(
            address(this),
            msg.sender,
            repayCache.debtAsset, 
            repayCache.debtAmount,
            ""
        );
        asset.safeTransferFrom(
            address(this),
            asset.caller(),
            repayCache.collateralAsset, 
            returnAmount,
            ""
        );
        repayCache.init = false;
    }
}
