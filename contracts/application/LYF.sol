// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../connector/sushi/SushiswapConnector.sol";
import "../valuation/Tokenization.sol";
import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/SyntheticNFT.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "../../interfaces/ILending.sol";
import "../test/WETH.sol";

contract LYF is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    DebtNFT public debtNFT;
    ILending public lending;
    SushiswapConnector public sushi;

    BorrowCache public borrowCache;
    BorrowCache public repayCache;

    struct BorrowCache {
        bool init;
        uint256[] collateralAssets;
        uint256[] collateralAmounts;
        uint256 debtAsset;
        uint256 debtAmount;
    }

    uint256 public sushiPoolId = 1;
    mapping(uint256 => SushiPool) public sushiPools;
    mapping(address => mapping(address => uint256)) public tokenToPool;
    mapping(uint256 => uint256) public lpToPool;

    struct SushiPool {
        uint256 pid;
        address token0;
        address token1;
        address lp;
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
        uint256[] memory assets,
        uint256[] memory amounts,
        uint256 debtAsset,
        uint256 debtAmount
    ) public {
        require(borrowCache.init == false, "already borrowed");
        borrowCache = BorrowCache(true, assets, amounts, debtAsset, debtAmount);

        for(uint256 i = 0; i < assets.length; i++) {
            asset.safeTransferFrom(msgSender(), address(this), assets[i], amounts[i], "");
        }
        uint256 pid = sushi.getPoolId(assets[0], assets[1]);
        uint256 nextTokenId = sushi.getNextTokenId(pid);
        uint256 id = lending.borrowAndCallback(nextTokenId, address(uint160(debtAsset)), debtAmount);

        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");

        delete borrowCache;
    }

    function borrowCallback() public override {
        require(borrowCache.init == true, "not borrowed");
        
        // Optimal Swap!!
        int256[] memory amounts = sushi.sell(borrowCache.debtAsset, borrowCache.collateralAssets[0], borrowCache.debtAmounts[0], 0);
        uint256 lp = sushi.getLP(borrowCache.collateralAssets[0], borrowCache.collateralAssets[1]);
        uint256 resA;
        uint256 resB;
        if (sushi.getToken0(lp) == borrowCache.collateralAssets[0]) {
            (resA, resB) = sushi.getReserves(borrowCache.collateralAssets[0], borrowCache.collateralAssets[1]);
        } else {
            (resB, resA) = sushi.getReserves(borrowCache.collateralAssets[0], borrowCache.collateralAssets[1]);
        }

        uint256 amtA = borrowCache.collateralAmounts[0];
        uint256 amtB = borrowCache.collateralAmounts[1];
        if (borrowCache.collateralAssets[0] == borrowCache.debtAsset) {
            amtA += borrowCache.debtAmount;
        } else {
            amtB += borrowCache.debtAmount;
        }
        int256[] memory amounts;
        (uint256 swapAmt, bool isReversed) = sushi.optimalDeposit(amtA, amtB, resA, resB);
        if (isReversed) {
            amounts = sushi.sell(borrowCache.collateralAmounts[1], borrowCache.collateralAmounts[0], swapAmt, 0);
        } else{
            amounts = sushi.sell(borrowCache.collateralAmounts[0], borrowCache.collateralAmounts[1], swapAmt, 0);
        }
        uint256[] memory mintTokens = new uint256[](2);
        uint256[] memory mintAmounts = new uint256[](2);
        uint256 poolId = sushi.getPoolId(mintTokens[0], mintTokens[1]);

        uint256 lpBalance = asset.balanceOf(address(this), lp);
        sushi.mint(mintTokens, mintAmounts);
        uint256 addBalance = asset.balanceOf(address(this), lp) - lpBalance;
        uint256 tokenId = sushi.depositNew(poolId, addBalance);

        asset.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
    }

    function close(uint256 debtId, uint256 ratioReturnToken) public {
        require(repayCache.init == false, "already repaid");
        repayCache.init = true;
        // (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
        //     .tokenInfos(debtId);
        // (uint256 debtAsset, uint256 debtAmount) = lending.getDebt(debtId);
        
        // repayCache = BorrowCache(true, collateralToken, collateralAmount, debtAsset, debtAmount);
        asset.safeTransferFrom(msgSender(), address(lending), debtId, 1, "");
        lending.repayAndCallback(debtId);
        repayCache.init = false;

        delete repayCache;
    }

    function repayCallback() public override {
        require(repayCache.init == true, "not repaid");
        // uint256 beforeBalance = asset.balanceOf(address(this), repayCache.collateralAsset);
        
        // Optimal Swap!! (+ debt)
        // sushi.buy(repayCache.collateralAsset, repayCache.debtAsset, repayCache.debtAmount, 0);
        // uint256 afterBalance = beforeBalance - asset.balanceOf(address(this), repayCache.collateralAsset);
        // uint256 returnAmount = repayCache.collateralAmount - (beforeBalance - afterBalance);
        
        uint256[] memory returnTokens = new uint256[](2);
        uint256[] memory returnAmounts = new uint256[](2);

        asset.safeTransferFrom(address(this), msg.sender, repayCache.debtAsset, repayCache.debtAmount, "");
        for (uint256 i = 0; i < returnTokens.length; i++) {
            asset.safeTransferFrom(address(this), msg.sender, returnTokens[i],  returnAmounts[i], "");
        }
        repayCache.init = false;
    }

    function _checkAndCreateSushiPool(
        address token0,
        address token1,
        address lp,
        uint256 pid
    ) internal {
        if (tokenToPool[token0][token1] != 0) return;

        sushiPools[sushiPoolId] = SushiPool(pid, token0, token1, lp);
        tokenToPool[token0][token1] = sushiPoolId;
        tokenToPool[token1][token0] = sushiPoolId;
        lpToPool[pid] = sushiPoolId;

        sushiPoolId++;
    }
}
