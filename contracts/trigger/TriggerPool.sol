// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/ITriggerLogic.sol";
import "../valuation/Tokenization.sol";
import "./library/TriggerBitmap.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract TriggerPool is AutomationCompatible {
    using TriggerBitmap for mapping(uint256 => uint256);

    /// ----- CONSTANTS -----
    uint8 internal constant SKIP = 0;
    uint8 internal constant PERFORM = 1;
    uint8 internal constant CANCEL = 2;

    struct TriggerInfo {
        address checkModule;
        bytes checkData;
        address performModule;
        bytes performData;
    }

    /// ----- VARIABLE STATES -----
    mapping(uint256 => TriggerInfo) public triggerInfos;
    mapping(uint256 => uint256) public triggerBitmap;

    /// ----- INIT STATES -----
    Tokenization public tokenization;
    IAsset public asset;

    /// ----- SETTING STATES -----
    uint256 public maxPage;
    uint256 public triggerCountPerPage;

    constructor(address _tokenization, address _asset) {
        tokenization = Tokenization(_tokenization);
        asset = IAsset(_asset);
    }

    /// @dev Register trigger order
    function registerTrigger(
        address checkModule,
        bytes calldata checkData,
        address performModule,
        bytes calldata performData
    ) public {
        uint256 triggerId = triggerBitmap.findFirstEmptySpace(triggerCountPerPage * maxPage / 256);
        triggerInfos[triggerId] = TriggerInfo(checkModule, checkData, performModule, performData);
    }

    function checkUpkeep(bytes calldata _checkData) external returns (bool upkeepNeeded, bytes memory performData) {
        (uint256 checkPage) = abi.decode(_checkData, (uint256));
        upkeepNeeded = false;
        uint8[] memory statusArray = new uint8[](triggerCountPerPage);
        for (uint i = checkPage * triggerCountPerPage; i < (checkPage + 1) * triggerCountPerPage; i ++) {
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
        for (uint i = 0; i < triggerCountPerPage; i ++) {
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

    function cancelTrigger(uint _triggerId) external {
        delete triggerInfos[_triggerId];
    }
}
