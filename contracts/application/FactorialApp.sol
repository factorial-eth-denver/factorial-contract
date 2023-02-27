// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IAsset.sol";

abstract contract FactorialApp {
    address public router;
    IAsset public factorial;

    function msgSender() internal view returns (address){
        if (msg.sender == router) {
            return factorial.caller();
        }
        return msg.sender;
    }
}
