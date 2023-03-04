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
import "../forDenver/Logging.sol";

contract LYF is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    struct BorrowCache {
        address caller;
        uint256[] inputAssets;
        uint256[] inputAmounts;
        uint256 debtAsset;
        uint256 debtAmount;
    }

    struct RepayCache {
        address caller;
        uint256 collateralAsset;
        uint256 collateralAmount;
        uint256 debtAsset;
        uint256 debtAmount;
    }

    BorrowCache public borrowCache;
    RepayCache public repayCache;
    DebtNFT public debtNFT;
    ILending public lending;
    Logging public logging;
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
        address _sushi,
        address _logging
    ) public initContext(_asset) {
        lending = ILending(_lending);
        debtNFT = DebtNFT(_deptNFT);
        sushiConnector = _sushi;
        logging = Logging(_logging);
    }

    // 깊은게 아니라 단순 토큰0을 담보로 토큰1을 빌려서 페어를 넣는다.
    function open(
        uint256[] memory assets,
        uint256[] memory amounts,
        uint256 debtAsset,
        uint256 debtAmount
    ) public {
        // 0. Validate states
        require(borrowCache.caller == address(0), "Already locked");
        require(assets[0] == debtAsset || assets[1] == debtAsset, "Borrow token only for LP");

        // 1. Caching params
        borrowCache = BorrowCache(msgSender(), assets, amounts, debtAsset, debtAmount);

        // 2. transfer assets from caller
        asset.safeBatchTransferFrom(msgSender(), address(this), assets, amounts, "");

        // 3. Borrow & callback
        uint256 pid = ISwapConnector(sushiConnector).getPoolId(assets[0], assets[1]);
        uint256 nextTokenId = ISwapConnector(sushiConnector).getNextTokenId(pid);
        uint256 id = lending.borrowAndCallback(nextTokenId, address(uint160(debtAsset)), debtAmount);
        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");
        logging.add(msgSender(), id, false);

        // 4. Delete cache
        delete borrowCache;
    }

    function borrowCallback() public override {
        /// 0. Declare local variable.
        uint256 assetA = borrowCache.inputAssets[0];
        uint256 assetB = borrowCache.inputAssets[1];
        uint256 debtToken = borrowCache.debtAsset;
        uint256 amtA = borrowCache.inputAmounts[0];
        uint256 amtB = borrowCache.inputAmounts[1];

        /// 1. Validate states
        require(borrowCache.caller != address(0), "Unlocked");
        require(assetA == debtToken || assetB == debtToken, "Borrow token only for LP");

        /// 2. Optimal swap before deposit
        {
            if (assetA == debtToken) {
                amtA += borrowCache.debtAmount;
            } else {
                amtB += borrowCache.debtAmount;
            }

            (uint256 swapAmt, bool isReversed) = ISwapConnector(sushiConnector).optimalSwapAmount(assetA, assetB, amtA, amtB);
            if (swapAmt != 0) {
                if (!isReversed) {
                    int[] memory swapOutput = IDexConnector(sushiConnector).sell(assetA, assetB, swapAmt, 0);
                    amtA -= swapAmt;
                    amtB += uint256(swapOutput[1]);
                } else {
                    int[] memory swapOutput = IDexConnector(sushiConnector).sell(assetB, assetA, swapAmt, 0);
                    amtA += uint256(swapOutput[1]);
                    amtB -= swapAmt;
                }
            }
        }

        /// 3. Mint LP token
        uint256 lpAmount;
        {
            uint256[] memory mintTokens = new uint256[](2);
            mintTokens[0] = assetA;
            mintTokens[1] = assetB;
            uint256[] memory mintAmounts = new uint256[](2);
            mintAmounts[0] = amtA;
            mintAmounts[1] = amtB;
            lpAmount = ISwapConnector(sushiConnector).mint(mintTokens, mintAmounts);
        }

        /// 4. Deposit & Transfer NFT to user.
        {
            uint256 poolId = ISwapConnector(sushiConnector).getPoolId(assetA, assetB);
            uint256 tokenId = ISwapConnector(sushiConnector).depositNew(poolId, lpAmount);
            asset.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
        }
    }

    function close(uint256 debtId, uint256 ratioReturnToken) public {
        /// 0. Validate states
        require(repayCache.caller == address(0), "Already locked");

        /// 1. Caching params
        (uint256 collateralToken, uint256 collateralAmount,) = debtNFT.tokenInfos(debtId);
        (uint256 debtAsset, uint256 debtAmount) = lending.getDebt(debtId);
        repayCache = RepayCache(msgSender(), collateralToken, collateralAmount, debtAsset, debtAmount);

        /// 2. transfer asset from sender
        asset.safeTransferFrom(msgSender(), address(lending), debtId, 1, "");

        /// 3. Repay & callback
        lending.repayAndCallback(debtId);

        /// 4. Delete cache
        delete repayCache;
    }

    function repayCallback() public override {
        /// 0. Validate states
        require(repayCache.caller != address(0), "Unlocked");

        /// 1. Declare local variable.
        uint256 debtToken = repayCache.debtAsset;
        uint256 debtAmount = repayCache.debtAmount;
        uint256 lp = ISwapConnector(sushiConnector).getUnderlyingLp(repayCache.collateralAsset);
        (uint256 assetA, uint assetB) = ISwapConnector(sushiConnector).getUnderlyingAssets(lp);

        /// 2. Withdraw & burn
        ISwapConnector(sushiConnector).withdraw(repayCache.collateralAsset, repayCache.collateralAmount);
        uint256[] memory assets = new uint256[](2);
        assets[0] = assetA;
        assets[1] = assetB;
        (uint256 amtA, uint256 amtB) = ISwapConnector(sushiConnector).burn(assets, repayCache.collateralAmount);

        /// 3. Swap for repay
        if (assetA == debtToken) {
            if (amtA >= debtAmount) {
                amtA -= debtAmount;
                debtAmount = 0;
            } else {
                debtAmount -= amtA;
                amtA = 0;
            }
            if (debtAmount > 0) {
                int[] memory swapOutput = IDexConnector(sushiConnector).buy(assetB, assetA, debtAmount, 0);
                amtB -= uint(swapOutput[0]);
            }
        } else {
            if (amtB >= debtAmount) {
                amtB -= debtAmount;
                debtAmount = 0;
            } else {
                debtAmount -= amtB;
                amtB = 0;
            }
            if (debtAmount > 0) {
                int[] memory swapOutput = IDexConnector(sushiConnector).buy(assetA, assetB, debtAmount, 0);
                amtA -= uint(swapOutput[0]);
            }
        }

        /// 4. Repay debt & transfer remaining assets to owner
        {
            asset.safeTransferFrom(address(this), msg.sender, repayCache.debtAsset, repayCache.debtAmount, "");
            uint256[] memory remainAmounts = new uint256[](2);
            remainAmounts[0] = amtA;
            remainAmounts[1] = amtB;
            asset.safeBatchTransferFrom(address(this), repayCache.caller, assets, remainAmounts, "");
        }
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