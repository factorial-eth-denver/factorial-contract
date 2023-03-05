// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

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

    uint256 public borrowFactor = 1.1e6;
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
        banks[_asset].totalDeposit += _amount;

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
         banks[_asset].totalDeposit -= _amount;

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
    ) external override returns (uint256) {
        asset.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(uint160(_asset)),
            _amount,
            ""
        );

        uint256 beforeAmount = asset.balanceOf(address(this), tokenId);
        IBorrowable(msg.sender).borrowCallback();
        uint256 amount = asset.balanceOf(address(this), tokenId) - beforeAmount;

        uint256 borrowValue = tokenization.getValue(
            uint256(uint160(_asset)),
            _amount
        );
        uint24 debtTypeId = 8585218;

        uint256 debtId = tokenization.wrap(
            debtTypeId,
            abi.encode(tokenId, amount, liquidationModule)
        );
        borrows[debtId] = BorrowInfo(_asset, _amount, block.timestamp);

        uint256 valueWithFactor = debtNFT.getValueWithFactor(address(this), debtId, 1);

        uint256 collValue = tokenization.getValue(tokenId, amount);
        uint256 debtValue = tokenization.getValue(uint256(uint160(_asset)), _amount);
        require(valueWithFactor != 0, "Lending: insufficient collateral");

        uint256 liquidationValue = Math.mulDiv(borrowFactor, borrowValue, 1e6);

        bytes memory performData;
        {
            performData = abi.encodeWithSignature(
                "execute(address,uint256,bytes)",
                liquidationModule,
                debtId,
                ""
            );
        }

        uint256 stopLossLogicId = 4;
        // uint256 stopLoss = liquidationValue;
        uint256 stopLoss = type(uint256).max;
        bytes memory checkData = abi.encodeWithSignature(
            "check(bytes)",
            abi.encode(debtId, uint256(1), stopLoss, address(this))
        );
        trigger.registerTrigger(
            address(this),
            debtId,
            1,
            stopLossLogicId,
            checkData,
            liquidation,
            performData
        );

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
        ) = debtNFT.tokenInfos(_debtId);
        (uint256 debtAsset, uint256 debtAmount) = getDebt(_debtId);
        tokenization.unwrap(_debtId, 1);
        asset.safeTransferFrom(address(this), msg.sender, collateralToken, collateralAmount, "");
        uint256 beforeAmount = asset.balanceOf(address(this), debtAsset);
        IBorrowable(msg.sender).repayCallback();
        uint256 amount = asset.balanceOf(address(this), debtAsset) - beforeAmount; 
        require(amount >= debtAmount,"Lending: insufficient collateral");

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
            ) = debtNFT.tokenInfos(_debtId);

            asset.safeTransferFrom(msgSender(), address(this), _debtId, 1, "");

            tokenization.unwrap(_debtId, 1);

            BorrowInfo storage borrowInfo = borrows[_debtId];

            asset.safeTransferFrom(
                msgSender(),
                address(this),
                uint256(uint160(borrowInfo.debtAsset)),
                borrowInfo.debtAmount + calcFee(_debtId),
                ""
            );

            asset.safeTransferFrom(
                address(this), 
                msgSender(), 
                collateralToken, 
                collateralAmount, 
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

    function getDebt(uint256 _debtId) public view returns (uint256, uint256) {
        BorrowInfo memory borrowInfo = borrows[_debtId];
        return (uint256(uint160(borrowInfo.debtAsset)), borrowInfo.debtAmount + calcFee(_debtId));
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
