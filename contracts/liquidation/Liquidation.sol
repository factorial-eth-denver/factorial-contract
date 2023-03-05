// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../valuation/Tokenization.sol";
import "../valuation/wrapper/DebtNFT.sol";
import "../../interfaces/ILiquidationModule.sol";
import "../../interfaces/ILending.sol";
import "../../interfaces/IAsset.sol";
import "../../interfaces/IRepayable.sol";

contract Liquidation is IRepayable, OwnableUpgradeable, FactorialContext, ERC1155HolderUpgradeable {
    Tokenization public tokenization;
    DebtNFT public debtNFT;
    address public trigger;

    RepayCache public repayCache;

    mapping(address => ILiquidationModule) public modules;

    function initialize(
        address _tokenization,
        address _debtNFT,
        address _trigger,
        address _factorialAsset
    ) initializer initContext(_factorialAsset) public {
        __Ownable_init();
        tokenization = Tokenization(_tokenization);
        debtNFT = DebtNFT(_debtNFT);
        trigger = _trigger;
        asset = IAsset(_factorialAsset);
    }

    function addModules(address[] calldata liquidationModules) public onlyOwner {
        for (uint256 i = 0; i < liquidationModules.length; ++i) {
            modules[liquidationModules[i]] = ILiquidationModule(
                liquidationModules[i]
            );
        }
    }

    function execute(
        address liquidationModule,
        uint256 tokenId,
        bytes calldata data
    ) public onlyTrigger {
        require(
            address(modules[liquidationModule]) != address(0),
            "Not registered"
        );

        address owner = asset.ownerOf(tokenId);
        asset.safeTransferFrom(
            owner,
            address(this),
            tokenId,
            1,
            ""
        );

        ILiquidationModule module = modules[liquidationModule];
        address liquidator = asset.caller();
        module.execute(liquidator, tokenId, data);
    }

    function liquidate(
        uint256 positionId,
        address[] calldata inAccounts,
        uint256[] calldata inAmounts,
        address[] calldata outAccounts,
        uint256[] calldata outAmounts
    ) public onlyLiquidationModule {
        require(repayCache.init == false, "already repaying");
        ILending lending = ILending(address(uint160(positionId)));
        uint256 collateralToken;
        uint256 debtToken;
        {
            uint256 _positionId = positionId;
            uint256 collateralAmount;
            (
                collateralToken,
                collateralAmount,
            ) = debtNFT.tokenInfos(_positionId);

            (uint256 debtAsset, uint256 debtAmount) = lending.getDebt(_positionId);
            debtToken = debtAsset;
            repayCache = RepayCache(
                true,
                collateralToken,
                collateralAmount,
                debtToken,
                debtAmount
            );
        }
        
        asset.safeTransferFrom(
            address(this),
            address(lending),
            positionId,
            1,
            ""
        );

        for (uint256 i = 0; i < inAccounts.length; ++i) {
            asset.safeTransferFrom(
                inAccounts[i],
                address(this),
                debtToken,
                inAmounts[i],
                ""
            );
        }

        lending.repayAndCallback(positionId);

        for (uint256 i = 0; i < outAccounts.length; ++i) {
            asset.safeTransferFrom(
                address(this),
                outAccounts[i],
                collateralToken,
                outAmounts[i],
                ""
            );
        }
        repayCache = RepayCache(false, 0, 0, 0, 0);
    }

    function repayCallback() public {
        require(repayCache.init == true, "not repaying");
        
        asset.safeTransferFrom(
            address(this),
            msg.sender,
            uint256(uint160(repayCache.debtAsset)),
            repayCache.debtAmount,
            ""
        );
    }

    modifier onlyTrigger() {
        require(msg.sender == trigger, "Not trigger");
        _;
    }

    modifier onlyLiquidationModule() {
        require(address(modules[msg.sender]) != address(0), "Not registered");
        _;
    }
}
