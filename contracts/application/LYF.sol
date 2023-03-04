// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../valuation/Tokenization.sol";
import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/SyntheticNFT.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "../../interfaces/ILending.sol";
import "../../interfaces/IDexConnector.sol";
import "../../interfaces/ISwapConnector.sol";

contract LYF is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    struct BorrowCache {
        bool init;
        uint256[] collateralAssets;
        uint256[] collateralAmounts;
        uint256 debtAsset;
        uint256 debtAmount;
    }

    BorrowCache public borrowCache;
    BorrowCache public repayCache;
    DebtNFT public debtNFT;
    ILending public lending;
    address public sushiConnector;

    struct SushiPool {
        uint256 pid;
        address token0;
        address token1;
        address lp;
    }

    uint256 public sushiPoolId = 1;
    mapping(uint256 => SushiPool) public sushiPools;
    mapping(address => mapping(address => uint256)) public tokenToPool;
    mapping(uint256 => uint256) public lpToPool;


    function initialize(
        address _asset,
        address _lending,
        address _deptNFT,
        address _sushi
    ) public initContext(_asset) {
        lending = ILending(_lending);
        debtNFT = DebtNFT(_deptNFT);
        sushiConnector = _sushi;
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
        for (uint256 i = 0; i < assets.length; i++) {
            asset.safeTransferFrom(msgSender(), address(this), assets[i], amounts[i], "");
        }
        uint256 pid = ISwapConnector(sushiConnector).getPoolId(assets[0], assets[1]);
        uint256 nextTokenId = ISwapConnector(sushiConnector).getNextTokenId(pid);
        uint256 id = lending.borrowAndCallback(nextTokenId, address(uint160(debtAsset)), debtAmount);
        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");
        delete borrowCache;
    }

    function borrowCallback() public override {
        /// 0. Declare local variable.
        uint256 collateralA = borrowCache.collateralAssets[0];
        uint256 collateralB = borrowCache.collateralAssets[1];
        uint256 debtToken = borrowCache.debtAsset;
        uint256 amtA = borrowCache.collateralAmounts[0];
        uint256 amtB = borrowCache.collateralAmounts[1];

        /// 1. Validate states
        require(borrowCache.init == true, "not borrowed");
        require(collateralA == debtToken || collateralB == debtToken, "Debt token only for LP");

        /// 2. Optimal swap before deposit
        {
            if (collateralA == debtToken) {
                amtA += borrowCache.debtAmount;
            } else {
                amtB += borrowCache.debtAmount;
            }

            (uint swapAmt, bool isReversed) = ISwapConnector(sushiConnector).optimalSwapAmount(collateralA, collateralB, amtA, amtB);
            if(isReversed) {
                int[] memory swapOutput = IDexConnector(sushiConnector).sell(collateralA, collateralB, swapAmt, 0);
                amtA -= swapAmt;
                amtB += uint256(swapOutput[1]);
            } else {
                int[] memory swapOutput = IDexConnector(sushiConnector).sell(collateralB, collateralA, swapAmt, 0);
                amtA += uint256(swapOutput[1]);
                amtB -= swapAmt;
            }
        }

        /// 3. Mint LP token
        uint256 mintedLP;
        {
            uint256[] memory mintTokens = new uint256[](2);
            mintTokens[0] = collateralA;
            mintTokens[1] = collateralB;
            uint256[] memory mintAmounts = new uint256[](2);
            mintAmounts[0] = amtA;
            mintAmounts[1] = amtB;
            ISwapConnector(sushiConnector).mint(mintTokens, mintAmounts);
        }

        /// 4. Deposit & Transfer NFT to user.
        {
            uint256 poolId = ISwapConnector(sushiConnector).getPoolId(collateralA, collateralB);
            uint256 tokenId = ISwapConnector(sushiConnector).depositNew(poolId, mintedLP);
            asset.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        }
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
            asset.safeTransferFrom(address(this), msg.sender, returnTokens[i], returnAmounts[i], "");
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