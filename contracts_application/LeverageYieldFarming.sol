// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Lending.sol";
import "../interfaces/IBorrowable.sol";

contract LeverageYieldFarming is IBorrowable, ERC1155, Ownable {
    // UniConnector public uni;
    Lending public lending;

    BorrowCache public borrowCache;
    BorrowCache public repayCache;

    struct BorrowCache {
        bool init;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
    }

    struct RepayCache {
        bool init;
        address collateral;
        address debt;
        uint256 collateralAmount;
        uint256 debtAmount;
    }

    constructor(address _fpm, address _uni, address _lending) ERC1155("") {
        // uni = UniConnector(_uni);
        lending = Lending(_lending);
    }

    // 깊은게 아니라 단순 토큰0을 담보로 토큰1을 빌려서 페어를 넣는다.
    function leverageFarm(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) public {
        require(borrowCache.init == false, "already borrowed");
        borrowCache = BorrowCache(true, token0, token1, amount0, amount1);

        lending.borrowAndCallback(token1, amount1);
        // fpm.mint([address(uni)], [id], [1], [token0, token1], [debt0, debt1]);
    }

    function borrowCallback()
        public
        override
        returns (uint256 tokenId, uint256 tokenAmount)
    {
        require(borrowCache.init == true, "not borrowed");

        // 스왑같은 코드 추가하려면 여기추가.

        // (tokenId, tokenAmount) = uni.mint(
        //     borrowCache.token0,
        //     borrowCache.token1,
        //     borrowCache.amount0,
        //     borrowCache.amount1
        // );

        borrowCache.init = false;
    }

    // 포지션을 뭘로받을지 정해야한다.
    function close(uint256 debtId, address closer, address receiver) public {
        // approve는 먼저해야됨.
        lending.repayAndCallback(debtId);
    }

    function repayCallback(
        uint256 tokenId,
        uint256 tokenAmount
    ) public override returns (uint256 dTokenId, uint256 dTokenAmount) {
        // (uint256 token0, uint256 amount0, uint256 token1, uint256 amount1) = uni
        //     .burn(collateral, collateralAmount);
        // uni.swap();

        sh

    }

    function getValue(uint256 id) public view returns (uint256) {
        return 0;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}
