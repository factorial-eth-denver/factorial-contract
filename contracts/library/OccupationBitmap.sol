// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import "./BitMath.sol";

library OccupationBitmap {
    using BitMath for uint;

    function toIdx(uint16 _contractId) internal pure returns (uint8 bitMapIdx, uint8 bitIdx) {
        bitMapIdx = uint8(_contractId >> 8);
        bitIdx = uint8(_contractId % 256);
    }

    function toContractId(uint8 _bitMapIdx, uint8 _bitIdx) internal pure returns (uint16 contractId) {
        contractId = (uint16(_bitMapIdx) << 8) + _bitIdx;
    }

    function occupy(mapping(uint8 => uint256) storage _self, uint16 _contractId) internal {
        (uint8 bitMapIdx, uint8 bitIdx) = toIdx(_contractId);
        uint256 mask = 1 << bitIdx;
        _self[bitMapIdx] |= mask;
    }

    function release(mapping(uint8 => uint256) storage _self, uint16 _contractId) internal {
        (uint8 bitMapIdx, uint8 bitIdx) = toIdx(_contractId);

        uint256 mask = 1 << bitIdx;
        uint256 diff = _self[bitMapIdx] & mask;
        _self[bitMapIdx] -= diff;
    }

    function findFirstEmptySpace(
        mapping(uint8 => uint) storage self,
        uint maxBitmapId
    ) internal view returns (uint16 nextContractId){
        (uint8 bitMapIdx, uint8 bitIdx) = toIdx(currentContractId);
        uint curBitmap;
        while (true) {
            curBitmap = self[bitMapIdx];
            if (curBitmap == 0) {
                require(bitMapIdx <= maxBitmapId, 'Not empty space');
                bitMapIdx = bitMapIdx + 1;
            } else {
                break;
            }
        }
        uint8 nextBitIdx = BitMath.leastSignificantBit(curBitmap);
        nextContractId = toContractId(bitMapIdx, nextBitIdx);
    }
}
