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
import "./Logging.sol";
import "../valuation/wrapper/DebtNFT.sol";
import "../valuation/wrapper/DebtNFT.sol";
import "./Logging.sol";

/// This is sample contract for denver demo without backend.
contract Logging {
    DebtNFT public debtNFT;
    ILending public lending;

    mapping(address => uint256[]) public tokens;
    mapping(address => bool[]) public isMarginToken;

    function initialize(
        address _debtNft,
        address _lending
    ) public {
        debtNFT = DebtNFT(_debtNft);
        lending = ILending(_lending);
    }

    struct Position {
        uint256 collateralToken;
        uint256 collateralAmount;
        uint256 debtToken;
        uint256 debtAmount;
        bool isMargin;
    }

    function add(address _user, uint256 _tokenId, bool _isMargin) external {
        tokens[_user].push(_tokenId);
        isMarginToken[_user].push(_isMargin);
    }

    function remove(address _user, uint256 _tokenId) public {
        delete tokens[_user];
    }

    function getStatus(address _user) external view returns (
        Position[] memory positions
    ){
        uint length = tokens[_user].length;
        positions = new Position[](length);

        uint writeId = 0;
        for (uint256 i = 0; i < length; i++) {
            uint tokenId = tokens[_user][i];
            (uint collateralToken, uint collateralAmount, ) = debtNFT.tokenInfos(tokenId);
            if(collateralAmount == 0) {
                continue;
            }
            (uint256 debtTokenId, uint256 debtAmount) = lending.getDebt(tokenId);
            positions[writeId].collateralToken = collateralToken;
            positions[writeId].collateralAmount = collateralAmount;
            positions[writeId].debtToken = debtTokenId;
            positions[writeId].debtAmount = debtAmount;
            positions[writeId].isMargin = isMarginToken[_user][i];
        }
    }
}