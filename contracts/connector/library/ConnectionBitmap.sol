// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import "./BitMath.sol";

library ConnectionBitmap {
    using BitMath for uint;

    function toIdx(uint24 _contractId) internal pure returns (uint16 bitMapIdx, uint8 bitIdx) {
        bitMapIdx = uint16(_contractId >> 8);
        bitIdx = uint8(_contractId % 256);
    }

    function toConnectionId(uint16 _bitMapIdx, uint8 _bitIdx) internal pure returns (uint24 connectionId) {
        connectionId = (uint24(_bitMapIdx) << 8) + _bitIdx;
    }

    function occupy(mapping(uint24 => uint) storage _self, uint24 _connectionId) internal {
        (uint16 bitMapIdx, uint8 bitIdx) = toIdx(_connectionId);
        uint256 mask = 1 << bitIdx;
        _self[bitMapIdx] |= mask;
    }

    function release(mapping(uint24 => uint) storage _self, uint24 _connectionId) internal {
        (uint16 bitMapIdx, uint8 bitIdx) = toIdx(_connectionId);

        uint256 mask = 1 << bitIdx;
        uint256 diff = _self[bitMapIdx] & mask;
        _self[bitMapIdx] -= diff;
    }

    function isEmpty(mapping(uint24 => uint) storage _self, uint24 _connectionId) internal view returns (bool) {
        (uint16 bitMapIdx, uint8 bitIdx) = toIdx(_connectionId);
        uint256 mask = 1 << bitIdx;
        return (_self[bitMapIdx] & mask != 0);
    }

    function findFirstEmptySpace(
        mapping(uint24 => uint) storage self,
        uint maxBitmapId
    ) internal view returns (uint24 nextContractId){
        uint16 bitMapIdx = 0;
        uint curBitmap;
        while (true) {
            curBitmap = ~self[bitMapIdx];
            if (curBitmap == 0) {
                require(bitMapIdx <= maxBitmapId, 'Not empty space');
                bitMapIdx = bitMapIdx + 1;
            } else {
                break;
            }
        }
        uint8 nextBitIdx = BitMath.leastSignificantBit(curBitmap);
        nextContractId = toConnectionId(bitMapIdx, nextBitIdx);
    }
}
