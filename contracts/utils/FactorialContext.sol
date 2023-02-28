// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../interfaces/IAsset.sol";

abstract contract FactorialContext {
    address public router;
    IAsset public asset;

    modifier initContext(address _asset) {
        asset = IAsset(_asset);
        router = asset.router();
        _;
    }

    function msgSender() internal view returns (address){
        if (msg.sender == router) {
            return asset.caller();
        }
        return msg.sender;
    }
}
