// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "./Lending.sol";

contract Margin is IBorrowable, ERC1155, Ownable {
    // UniConnector public uni;
    DebtNFT public debtNFT;
    Lending public lending;

    BorrowCache public borrowCache;
    RepayCache public repayCache;

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

    struct RepayCache {
        bool init;
        uint256 debtAsset;
        uint256 debtAmount;
        uint256 collateralAsset;
        uint256 collateralAmount;
    }

    constructor(address _fpm, address _uni, address _lending) ERC1155("") {
        // uni = UniConnector(_uni);
        lending = Lending(_lending);
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

    // 깊은게 아니라 단순 토큰0을 담보로 토큰1을 빌려서 페어를 넣는다.
    function leverageTrade(
        bool isBuy,
        address collateralAsset,
        address debtAsset,
        uint256 collateralAmount,
        uint256 debtAmount
    ) public {
        require(borrowCache.init == false, "already borrowed");
        // borrowCache = BorrowCache(true, collateralAsset, debtAsset, collateralAmount, debtAmount);

        // lending.borrowAndCallback(debtAsset, debtAmount);
        // fpm.mint([address(uni)], [id], [1], [token0, token1], [debt0, debt1]);
    }

    function borrowCallback()
        public
        override
    {
        require(borrowCache.init == true, "not borrowed");

        // 스왑같은 코드 추가하려면 여기추가.

        // uint256 liquidity = sushi.mint(
        //     borrowCache.collateralAsset,
        //     borrowCache.debtAsset,
        //     borrowCache.collateralAmount,
        //     borrowCache.debtAmount
        // );
        // uint256 lpAddress = sushi.getLP(borrowCache.collateralAsset, borrowCache.debtAsset);
        // uint256 lpId = sushi.getPoolId(borrowCache.collateralAsset, borrowCache.debtAsset);
        // tokenId = sushi.deposit(lpId, liquidity);
        // tokenAmount = 1;

        // _checkAndCreateSushiPool(
        //     borrowCache.collateralAsset, 
        //     borrowCache.debtAsset,
        //     lpAddress,
        //     lpId
        // );

        borrowCache.init = false;
    }

    // 포지션을 뭘로받을지 정해야한다.
    function close(uint256 debtId, address closer, address receiver) public {
        require(repayCache.init == false, "already repaid");

        // (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
        //     .tokenInfos(debtId);
        // (address debtAsset, uint256 debtAmount) = lending.getDebt(debtId);

        // repayCache = RepayCache(
        //     true,
        //     debtAsset,
        //     debtAmount,
        //     collateralToken,
        //     collateralAmount
        // );
        lending.repayAndCallback(debtId);
    }

    function repayCallback()
        public
        override
    {
        require(repayCache.init == true, "not repaid");

        // sushi.withdraw(repayCache.collateralAsset, repayCache.collateralAmount);
        // 이렇게하면 어차피 NFT라서 liquidity갯수를 모르지 않나?

        // SushiPool memory pool = sushiPools[lpToPool[tokenId]];
        // (uint256 amount0, uint256 amount1) = sushi.burn(
        //     repayCache.collateralAsset,
        //     repayCache.deptAsset,
        //     tokenAmount
        // );

        // if (repayCache.deptAsset == ) {

        // }

        // (uint256 token0, uint256 amount0, uint256 token1, uint256 amount1) = uni
        //     .burn(collateral, collateralAmount);
        // uni.swap();

        repayCache.init = false;
    }

    function getValue(uint256 id) public view returns (uint256) {
        return 0;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}
