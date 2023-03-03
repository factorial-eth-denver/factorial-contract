// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MockTriggerHandler {

    Params public params;

    struct Params {
        uint256 test1;
        uint256 test2;
        uint256 test3;
        uint256 test4;
    }


    function trigger(bytes calldata _params) public {
        Params memory p = abi.decode(_params, (Params));
        
        console.log("TriggerCallback: trigger");
        console.log("TriggerCallback: test1", p.test1);
        console.log("TriggerCallback: test2", p.test2);
        console.log("TriggerCallback: test3", p.test3);
        console.log("TriggerCallback: test4", p.test4);

        params = Params(
            p.test1,
            p.test2,
            p.test3,
            p.test4
        );
    }

}
