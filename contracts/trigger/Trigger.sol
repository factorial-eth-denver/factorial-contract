// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./library/TriggerBitmap.sol";
import "../utils/FactorialContext.sol";
import "../valuation/Tokenization.sol";
import "../../interfaces/ITriggerLogic.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Trigger is AutomationCompatible, OwnableUpgradeable, FactorialContext {
    using TriggerBitmap for mapping(uint256 => uint256);

    uint8 internal constant SKIP = 0;
    uint8 internal constant PERFORM = 1;
    uint8 internal constant CANCEL = 2;

    mapping(uint256 => TriggerInfo) public triggerInfos;

    uint256 public triggerTypeId = 1;
    mapping(uint256 => uint256) public triggerBitmap;
    mapping(uint256 => address) public triggerLogics;

    uint256 public maxPage;
    uint256 public triggerCountPerPage;

    event RegisterTrigger(uint256 triggerId);
    event CancelTrigger(uint256 triggerId);
    event ExecuteTrigger(uint256 triggerId);
    event FailTrigger(uint256 triggerId);

    struct TriggerInfo {
        address owner;
        address checkModule;
        bytes checkData;
        address performModule;
        bytes performData;
    }

    function initialize(address _asset, uint256 _maxPage, uint256 _triggerCountPerPage) public initializer initContext(_asset) {
        __Ownable_init();
        asset = IAsset(_asset);
        maxPage = _maxPage;
        triggerCountPerPage = _triggerCountPerPage;
    }

    function addTriggerLogic(address triggerLogic) public onlyOwner {
        triggerLogics[triggerTypeId] = triggerLogic;
        triggerTypeId++;
    }

    // 가지고 있어야
    function registerTrigger(
        address owner,
        uint256 collateralToken, // 토큰을 가지고 있는사람만 본인이 등록가능해야함.
        uint256 collateralAmount,
        uint256 triggerLogicId,
        bytes calldata triggerCheckData,
        address performModule,
        bytes calldata performData
    ) public returns (uint256 triggerId) {
        require(
            asset.balanceOf(msgSender(), collateralToken) >= collateralAmount,
            "Not Enough Collateral"
        );
        require(triggerLogics[triggerLogicId] != address(0), "Not Exist TriggerLogic");

        triggerId = triggerBitmap.findFirstEmptySpace(triggerCountPerPage * maxPage / 256);

        triggerInfos[triggerId] = TriggerInfo(
            owner,
            triggerLogics[triggerLogicId],
            triggerCheckData,
            performModule,
            performData
        );
        triggerBitmap.occupy(triggerId);

        emit RegisterTrigger(triggerId);
    }

    // owner가 적혀야되는지 정확한 판단되는지 청산취소못하게 되는지.
    function cancelTrigger(uint256 triggerId) public {
        TriggerInfo storage triggerInfo = triggerInfos[triggerId];

        require(msgSender() == triggerInfo.owner, "Not Owner");
        delete triggerInfos[triggerId];

        emit CancelTrigger(triggerId);
    }

    function checkUpkeep(bytes calldata _checkData) external view returns (bool upkeepNeeded, bytes memory performData) {
        (uint256 checkPage) = abi.decode(_checkData, (uint256));
        upkeepNeeded = false;
        uint8[] memory statusArray = new uint8[](triggerCountPerPage);
        for (uint i = checkPage * triggerCountPerPage; i < (checkPage + 1) * triggerCountPerPage; ++i) {
            TriggerInfo memory triggerInfo = triggerInfos[uint24(i)];
            (bool success, bytes memory data) = triggerInfo.checkModule.staticcall(
                triggerInfo.checkData
            );
            if (success && data.length > 0) {
                bool isPerform = abi.decode(data, (bool));
                if (isPerform) {
                    statusArray[i] = PERFORM;
                    upkeepNeeded = true;
                }
            } else {
                statusArray[i] = CANCEL;
            }
        }
        performData = abi.encode(checkPage, statusArray);
    }

    function performUpkeep(bytes calldata performData) external {
        (uint256 page, uint8[] memory statusArray) = abi.decode(performData, (uint256, uint8[]));
        for (uint i = 0; i < triggerCountPerPage; ++i) {
            TriggerInfo memory triggerInfo = triggerInfos[page * triggerCountPerPage + i];
            if (statusArray[i] == PERFORM) {
                (bool success, bytes memory data) = triggerInfo.performModule.call(
                    triggerInfo.performData
                );
            }
            if (statusArray[i] != SKIP) {
                triggerBitmap.release(page * triggerCountPerPage + i);
                delete triggerInfos[page * triggerCountPerPage + i];
            }
        }
    }

    function executeTrigger(uint256 triggerId) public {
        TriggerInfo storage triggerInfo = triggerInfos[triggerId];

        (bool success, bytes memory data) = triggerInfo.checkModule.staticcall(
            triggerInfo.checkData
        );

        if (!success) revert("Not Executable");
        (bool ok, bytes memory returndata) = triggerInfo.performModule.call(
            triggerInfo.performData
        );
        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("Trigger: bad execute call");
            }
        }
        emit ExecuteTrigger(triggerId);
    }
}
