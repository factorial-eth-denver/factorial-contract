// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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

        params = Params(
            p.test1,
            p.test2,
            p.test3,
            p.test4
        );
    }

}
