// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IBorrowable.sol";
import "../interfaces/ILending.sol";
import "../interfaces/IAsset.sol";

import "../contracts/valuation/Tokenization.sol";
import "../contracts/valuation/wrapper/DebtNFT.sol";
import "../contracts/trigger/Trigger.sol";
import "../contracts/trigger/logics/TriggerStopLoss.sol";

contract Lending is ILending, ERC1155, ERC1155Supply, Ownable {
    struct Bank {
        uint256 totalDeposit;
        bool isWhitelisted;
    }

    Tokenization public tokenization;
    Trigger public trigger;
    DebtNFT public debtNFT;
    IAsset public asset;
    address public liquidation;

    uint256 public borrowFactor;
    uint256 public borrowFeeRatio = 6341958396; // 0.2e18 / (365 * 24 * 3600)

    mapping(address => Bank) public banks;
    mapping(uint256 => BorrowInfo) public borrows;

    constructor() ERC1155("Lending") {}

    function getBorrowInfo(
        uint256 _id
    ) external view override returns (BorrowInfo memory) {
        return borrows[_id];
    }

    function deposit(address _asset, uint256 _amount) external {
        require(banks[_asset].isWhitelisted, "Lending: asset not whitelisted");
        asset.safeTransferFrom(
            msg.sender,
            address(this),
            uint256(uint160(_asset)),
            _amount,
            ""
        );

        uint256 share = convertToShare(_asset, _amount);
        _mint(msg.sender, uint256(uint160(_asset)), share, "");
    }

    function withdraw(address _asset, uint256 _amount) external {
        uint256 share = convertToShare(_asset, _amount);
        _burn(msg.sender, uint256(uint160(_asset)), share);

        asset.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(uint160(_asset)),
            _amount,
            ""
        );
    }

    // [수정] erc20 -> erc1155
    function borrowAndCallback(
        address _asset,
        uint256 _amount
    ) external onlyOwner {
        asset.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(uint160(_asset)),
            _amount,
            ""
        );

        (uint256 tokenId, uint256 amount) = IBorrowable(msg.sender)
            .borrowCallback();

        uint256 borrowValue = tokenization.getValue(
            uint256(uint160(_asset)),
            _amount
        );
        uint256 positionValue = tokenization.getValue(tokenId, amount);
        require(
            positionValue * borrowFactor >= borrowValue,
            "Lending: insufficient collateral"
        );

        // 추가해줘야함
        uint24 deptTypeId;
        address liquidationModule;

        // [수정] deptId를 리턴해주게 변경
        uint256 debtId = tokenization.wrap(
            deptTypeId,
            abi.encode(tokenId, amount, liquidationModule)
        );
        borrows[debtId] = BorrowInfo(_asset, _amount, block.timestamp);

        // encode 데이터 넣어야함
        //  uint256 collateralToken,
        // uint256 collateralAmount,
        // bytes calldata triggerCheckData,
        // address triggerTarget,
        // bytes calldata triggerCalldata

        uint256 stopLossLogicId;
        uint256 stopLoss;
        bytes memory triggerCheckData = abi.encodePacked(stopLoss);
        address liquidationAddress;

        uint256 positionId;
        address liquidator;
        address prevOwner;

        bytes memory liquidateCalldata = abi.encodePacked(
            positionId,
            liquidator,
            prevOwner
        );

        bytes memory triggerCalldata = abi.encodeWithSignature(
            "execute(address,bytes)",
            liquidationAddress,
            liquidateCalldata
        );

        // trigger.registerTrigger(debtId, 1, 0.15e12, 0, 0, liquidation, "");
    }

    function repayAndCallback(uint256 _debtId) public {
        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(_debtId);
        require(debtNFT.ownerOf(_debtId) == msg.sender, "UA");
        debtNFT.unwrap(_debtId, 1);

        (uint256 tokenId, uint256 amount) = IBorrowable(msg.sender)
            .repayAndCallback();

        BorrowInfo storage borrowInfo = borrows[_debtId];

        tokenization.safeTransferFrom(
            msg.sender,
            address(this),
            borrowInfo.debtAsset,
            borrowInfo.debtAmount + calcFee(_debtId),
            ""
        );

        borrows[_debtId].debtAmount = 0;
        borrows[_debtId].debtAsset = 0;
        borrows[_debtId].startTime = 0;
    }

    function liquidate(uint256 _debtId) public override {
        uint256 isOwner = tokenization.balanceOf(msg.sender, _debtId) != 0
            ? true
            : false;

        if (isOwner) {
            (
                uint256 collateralToken,
                uint256 collateralAmount,
                address liquidationModule
            ) = debtNFT.tokenInfos(_debtId);

            debtNFT.unwrap(_debtId, 1);

            BorrowInfo storage borrowInfo = borrows[_debtId];

            tokenization.safeTransferFrom(
                msg.sender,
                address(this),
                borrowInfo.debtAsset,
                borrowInfo.debtAmount + calcFee(_debtId),
                ""
            );

            borrows[_debtId].debtAmount = 0;
            borrows[_debtId].debtAsset = 0;
            borrows[_debtId].startTime = 0;
        }
    }

    function calcFee(uint256 _debtId) public view returns (uint256) {
        BorrowInfo memory borrowInfo = borrows[_debtId];

        uint256 fee = Math.mulDiv(borrowInfo.debtAmount, borrowFeeRatio, 1e18);
        uint256 duration = block.timestamp - borrowInfo.startTime;
        return fee * duration;
    }

    function convertToShare(
        address _asset,
        uint256 amount
    ) public view returns (uint256) {
        uint256 _totalDepsoit = banks[_asset].totalDeposit;
        uint256 _totalSupply = totalSupply(uint256(uint160(_asset)));

        return
            _totalDepsoit == 0
                ? amount
                : Math.mulDiv(_totalSupply, amount, _totalDepsoit);
    }

    function convertToAmount(
        address _asset,
        uint256 share
    ) public view returns (uint256) {
        uint256 _totalDepsoit = banks[_asset].totalDeposit;
        uint256 _totalSupply = totalSupply(uint256(uint160(_asset)));

        return
            _totalSupply == 0
                ? share
                : Math.mulDiv(_totalDepsoit, share, _totalSupply);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
