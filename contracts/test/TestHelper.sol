// SPDX-License-Identifier: UNLICENSED

pragma solidity >= 0.8.0;

contract TestHelper {
    function extractAddressFromTokenId(uint256 _tokenId) external pure returns (address) {
        return address(uint160(_tokenId));
    }

    function convertAddressToId(address _tokenAddress) external pure returns (uint256) {
        return uint256(uint160(_tokenAddress));
    }

    function combineToId(uint24 _tokenType, uint256 _sequentialN, address _address) external pure returns (uint256) {
        return (uint256(_tokenType) << 232) + (_sequentialN << 160) + uint256(uint160(_address));
    }
}