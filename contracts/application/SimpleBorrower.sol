// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../interfaces/IBorrowable.sol";
import "../../contracts/valuation/wrapper/SyntheticNFT.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "./Lending.sol";

contract SimpleBorrower is IBorrowable, ERC1155HolderUpgradeable, FactorialContext {
    Tokenization public tokenization;
    SyntheticNFT public syntheticNFT;
    DebtNFT public debtNFT;
    Lending public lending;

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
        address _tokenization,
        address _asset,
        address _lending,
        address _syntheticNFT,
        address _deptNFT
    ) public initContext(_asset) {
        tokenization = Tokenization(_tokenization);
        lending = Lending(_lending);
        syntheticNFT = SyntheticNFT(_syntheticNFT);
        debtNFT = DebtNFT(_deptNFT);
    }

    function borrow(
        address collateralAsset,
        uint256 collateralAmount,
        address debtAsset,
        uint256 debtAmount
    ) public {
        require(borrowCache.init == false, "already borrowed");
        borrowCache.init = true;

        asset.safeTransferFrom(msgSender(), address(this), uint256(uint160(collateralAsset)), collateralAmount, "");
        borrowCache = BorrowCache(true, uint256(uint160(collateralAsset)), collateralAmount, uint256(uint160(debtAsset)), debtAmount);
        uint24 syntheticNFTTypeId = 8519684;
        uint256 tokenId = syntheticNFT.getNextTokenId(address(this), syntheticNFTTypeId);
        uint256 id = lending.borrowAndCallback(tokenId, debtAsset, debtAmount);

        asset.safeTransferFrom(address(this), msgSender(), id, 1, "");
    }

    function borrowCallback()
        public
        override
    {
        require(borrowCache.init == true, "not borrowed");
        
        uint256[] memory tokens = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = uint256(uint160(borrowCache.collateralAsset));
        amounts[0] = borrowCache.collateralAmount;
        tokens[1] = uint256(uint160(borrowCache.debtAsset));
        amounts[1] = borrowCache.debtAmount;
        uint24 syntheticNFTTypeId = 8519684;

        uint256 tokenId = tokenization.wrap(syntheticNFTTypeId, abi.encode(tokens, amounts));
        uint256 tokenAmount = 1;

        asset.safeTransferFrom(address(this), msg.sender, tokenId, tokenAmount, "");

        borrowCache.init = false;
    }

    function repay(uint256 debtId) public {
        require(repayCache.init == false, "already repaid");
        repayCache.init = true;

        (uint256 collateralToken, uint256 collateralAmount, ) = debtNFT
            .tokenInfos(debtId);
        (uint256 debtAsset, uint256 debtAmount) = lending.getDebt(debtId);
        
        asset.safeTransferFrom(msgSender(), address(lending), debtId, 1, "");
        repayCache = BorrowCache(
            true,
            collateralToken,
            collateralAmount,
            debtAsset,
            debtAmount
        );

        lending.repayAndCallback(debtId);
    }

    function repayCallback()
        public
        override
    {
        require(repayCache.init == true, "not repaid");

        (uint256[] memory tokens, uint256[] memory amounts) =
             syntheticNFT.getTokenInfo(repayCache.collateralAsset);

        tokenization.unwrap(
            repayCache.collateralAsset, 
            repayCache.collateralAmount
        );

        for (uint256 i = 0; i < tokens.length; ++i) {
            if (tokens[i] == uint256(uint160(repayCache.debtAsset))) {
                if (repayCache.debtAmount > amounts[i]) {
                    asset.safeTransferFrom(
                        asset.caller(),
                        address(this), 
                        tokens[i], 
                        repayCache.debtAmount - amounts[i],
                        ""
                    );
                    amounts[i] += repayCache.debtAmount - amounts[i];
                }
                uint256 restAmount = amounts[i] - repayCache.debtAmount;
                asset.safeTransferFrom(
                    address(this), 
                    msg.sender, 
                    tokens[i], 
                    amounts[i] - restAmount,
                    ""
                );
                if (restAmount > 0) {
                    asset.safeTransferFrom(
                        address(this), 
                        asset.caller(), 
                        tokens[i], 
                        restAmount,
                        ""
                    );
                }
            } else {
                asset.safeTransferFrom(
                    address(this), 
                    asset.caller(), 
                    tokens[i], 
                    amounts[i],
                    ""
                );
            }
            
        }

        repayCache.init = false;
    }
}
