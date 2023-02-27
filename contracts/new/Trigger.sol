// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../Tokenization.sol";
import "./interfaces/ITriggerLogic.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Trigger {
    Tokenization public tokenization;

    //  16 bit = triggerLogicId
    // 240 bit = triggerId
    mapping(uint256 => TriggerInfo) public triggerInfos;

    event RegisterTrigger(uint256 triggerId);
    event CancelTrigger(uint256 triggerId);
    event ExecuteTrigger(uint256 triggerId);
    event FailTrigger(uint256 triggerId);

    uint256 public triggerTypeId = 1;
    mapping(uint256 => ITriggerLogic) public triggerLogics;
    mapping(uint256 => uint256) public triggerLastIndex;

    // mapping key를 따로 뺄지는 나중에 정하기.
    struct TriggerInfo {
        uint256 owner;
        uint256 initialValue;
        uint256 collateralToken;
        uint256 collateralAmount;
        bytes triggerCheckData;
        bool isCanceled;
        bool isExectued;
        address triggerTarget;
        bytes triggerCalldata;
    }

    constructor(uint _tokenization) payable {
        tokenization = Tokenization(_tokenization);
    }

    function addTriggerLogic(address triggerLogic) public {
        triggerLogics[triggerTypeId] = ITriggerLogic(triggerLogic);
        triggerLastIndex[triggerTypeId] = 1;
        triggerTypeId++;
    }

    function registerTrigger(
        uint256 triggerLogicId,
        uint256 collateralToken,
        uint256 collateralAmount,
        bytes triggerCheckData,
        address triggerTarget,
        bytes triggerCalldata
    ) public {
        require(msg.sender == tokenization.ownerOf(collateralToken), "E1");
        require(triggerLogics[triggerLogicId] != address(0), "NE");

        uint256 _initialValue = tokenization.getValue(
            collateralToken,
            collateralAmount
        );

        triggerInfos.push(
            TriggerInfo(
                msg.sender,
                _initialValue,
                collateralToken,
                collateralAmount,
                triggerCheckData,
                false,
                false,
                triggerTarget,
                triggerCalldata
            )
        );

        emit RegisterTrigger(triggerInfos.length - 1);
    }

    function cancelTrigger(uint256 triggerId) public {
        TriggerInfo storage triggerInfo = triggerInfos[triggerId];

        require(msg.sender == triggerInfo.owner, "E2");
        triggerInfo.isCanceled = false;

        emit CancelTrigger(triggerId);
    }

    // 고민해야하는게 어떤에러가 뜨느냐에 따라서 지우거나 해야함.
    function executeTrigger(uint256 triggerId) public {
        TriggerInfo storage triggerInfo = triggerInfos[triggerId];
        require(triggerInfo.isCanceled == false, "E3");
        require(triggerInfo.isExectued == false, "E4");

        uint256 currentValue = tokenization.getValue(
            collateralToken,
            collateralAmount
        );

        bool isExecutable = triggerLogics[triggerLogicId].check(
            triggerInfo.initialValue,
            currentValue,
            triggerInfo.triggerCheckData
        );

        if (!isExecutable) revert("NR");
        (bool ok, bytes memory returndata) = triggerInfo.triggerTarget.call(
            triggerInfo.triggerCalldata
        );

        if (!ok) {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("bad execute call");
            }
        }

        triggerInfo.isExectued = true;
        emit ExecuteTrigger(triggerId);
    }
}
