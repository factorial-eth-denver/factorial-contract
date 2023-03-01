// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

// import "@openzeppelin/contracts-upgradable/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../utils/FactorialContext.sol";

import "../../interfaces/IBorrowable.sol";
import "../../interfaces/ILending.sol";
import "../../interfaces/IAsset.sol";

import "../../contracts/valuation/Tokenization.sol";
import "../../contracts/valuation/wrapper/DebtNFT.sol";
import "../../contracts/trigger/Trigger.sol";
import "../../contracts/trigger/logics/TriggerStopLoss.sol";

contract Lending is ILending, ERC1155Upgradeable, ERC1155SupplyUpgradeable, OwnableUpgradeable, FactorialContext {
    struct Bank {
        uint256 totalDeposit;
        bool isWhitelisted;
    }

    Tokenization public tokenization;
    Trigger public trigger;
    DebtNFT public debtNFT;
    address public liquidation;
    address public liquidationModule;

    uint256 public borrowFactor = 1.1e18;
    uint256 public borrowFeeRatio = 6341958396; // 0.2e18 / (365 * 24 * 3600)

    mapping(address => Bank) public banks;
    mapping(uint256 => BorrowInfo) public borrows;

    function initialize(
        address _tokenization,
        address _debtNFT,
        address _trigger,
        address _factorialAsset,
        address _liquidation,
        address _liquidationModule
    ) public initializer initContext(_factorialAsset) {
        __Ownable_init();
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
        trigger = Trigger(_trigger);
        asset = IAsset(_factorialAsset);
        liquidation = _liquidation;
        liquidationModule = _liquidationModule;
    }

    function getBorrowInfo(
        uint256 _id
    ) external view override returns (BorrowInfo memory) {
        return borrows[_id];
    }

    function addBank(address _asset) external onlyOwner {
        banks[_asset].isWhitelisted = true;
    }

    function deposit(address _asset, uint256 _amount) external {
        require(banks[_asset].isWhitelisted, "Lending: asset not whitelisted");

        asset.safeTransferFrom(
            msgSender(),
            address(this),
            uint256(uint160(_asset)),
            _amount,
            ""
        );

        uint256 share = convertToShare(_asset, _amount);
        _mint(msgSender(), uint256(uint160(_asset)), share, "");
    }

    function withdraw(address _asset, uint256 _amount) external {
        uint256 share = convertToShare(_asset, _amount);
        _burn(msgSender(), uint256(uint160(_asset)), share);

        asset.safeTransferFrom(
            address(this),
            msgSender(),
            uint256(uint160(_asset)),
            _amount,
            ""
        );
    }

    // [수정] erc20 -> erc1155
    function borrowAndCallback(
        uint256 tokenId,
        address _asset,
        uint256 _amount
    ) external returns (uint256) {

        asset.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(uint160(_asset)),
            _amount,
            ""
        );

        uint256 beforeAmount = asset.balanceOf(address(this), tokenId);
        // IBorrowable(msgSender()).borrowCallback();
        IBorrowable(msg.sender).borrowCallback();
        uint256 amount = asset.balanceOf(address(this), tokenId) - beforeAmount;

        uint256 borrowValue = tokenization.getValue(
            uint256(uint160(_asset)),
            _amount
        );
        uint256 positionValue = tokenization.getValue(tokenId, amount);
        console.log("borrowValue adjust  : ", Math.mulDiv(borrowFactor, borrowValue, 1e18));
        console.log("   positionValue    : ", positionValue);

        
        require(
            positionValue > Math.mulDiv(borrowFactor, borrowValue, 1e18),
            "Lending: insufficient collateral"
        );

        // 추가해줘야함
        uint24 deptTypeId = 131074;
        uint256 debtId = tokenization.wrap(
            deptTypeId,
            abi.encode(tokenId, amount, liquidationModule)
        );
        console.log("debtId", debtId);

        uint256 _tokenId = tokenId;
        borrows[debtId] = BorrowInfo(_asset, _amount, block.timestamp);
        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(debtId);
        console.log("collateralToken  ", collateralToken);
        console.log("collateralAmount ", collateralAmount);
        console.log("debt token       ", borrows[debtId].debtAsset);
        console.log("debt amount      ", borrows[debtId].debtAmount);

       

        bytes memory triggerCalldata;
        {

            bytes memory liquidateCalldata = abi.encodePacked(
                msgSender()
            );

            triggerCalldata = abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                liquidation,
                debtId,
                liquidateCalldata
            );
        }

        uint256 stopLossLogicId = 1;
        uint256 stopLoss = 1000000000;
        bytes memory triggerCheckData = abi.encodePacked(stopLoss);


        //  address owner,
        // uint256 collateralToken,
        // uint256 collateralAmount,
        // uint256 triggerLogicId,
        // bytes calldata triggerCheckData,
        // address triggerTarget,
        // bytes calldata triggerCalldata

        trigger.registerTrigger(
            address(this),
            _tokenId,
            1,
            stopLossLogicId,
            triggerCheckData,
            liquidation,
            triggerCalldata
        );

        // 트리거의 오너만 트리거를 취소할 수 있게해야함. 오너를 설정할수 있게 해야함.
        asset.safeTransferFrom(
            address(this),
            msg.sender,
            debtId,
            1,
            ""
        );

        return debtId;

    }

    function repayAndCallback(uint256 _debtId) public {
        (
            uint256 collateralToken,
            uint256 collateralAmount,
            address liquidationModule
        ) = debtNFT.tokenInfos(_debtId);

        tokenization.unwrap(_debtId, 1);

        (uint256 tokenId, uint256 amount) = IBorrowable(msgSender())
            .repayCallback();
        BorrowInfo storage borrowInfo = borrows[_debtId];

        asset.safeTransferFrom(
            msgSender(),
            address(this),
            uint256(uint160(borrowInfo.debtAsset)),
            borrowInfo.debtAmount + calcFee(_debtId),
            ""
        );
        require(uint256(uint160(borrowInfo.debtAsset)) == tokenId && borrowInfo.debtAmount <= amount,"Lending: insufficient collateral");

        borrows[_debtId].debtAmount = 0;
        borrows[_debtId].debtAsset = address(0);
        borrows[_debtId].startTime = 0;
    }

    function liquidate(uint256 _debtId) public override {
        bool isOwner = asset.balanceOf(msgSender(), _debtId) != 0
            ? true
            : false;

        if (isOwner) {
            (
                uint256 collateralToken,
                uint256 collateralAmount,
                address liquidationModule
            ) = debtNFT.tokenInfos(_debtId);

            tokenization.unwrap(_debtId, 1);

            BorrowInfo storage borrowInfo = borrows[_debtId];

            asset.safeTransferFrom(
                msgSender(),
                address(this),
                uint256(uint160(borrowInfo.debtAsset)),
                borrowInfo.debtAmount + calcFee(_debtId),
                ""
            );

            borrows[_debtId].debtAmount = 0;
            borrows[_debtId].debtAsset = address(0);
            borrows[_debtId].startTime = 0;
        }
    }

    function calcFee(uint256 _debtId) public view returns (uint256) {
        BorrowInfo memory borrowInfo = borrows[_debtId];

        uint256 fee = Math.mulDiv(borrowInfo.debtAmount, borrowFeeRatio, 1e18);
        uint256 duration = block.timestamp - borrowInfo.startTime;
        return fee * duration;
    }

    function getDebt(uint256 _debtId) public view returns (address, uint256) {
        BorrowInfo memory borrowInfo = borrows[_debtId];
        return (borrowInfo.debtAsset, borrowInfo.debtAmount + calcFee(_debtId));
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
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
