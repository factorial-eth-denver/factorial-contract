// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITriggerAction {
    function trigger(uint256 wrappingTokenId, uint256 tokenId, uint256 tokenAmount) external;
}
