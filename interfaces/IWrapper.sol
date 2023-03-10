// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWrapper {
    function wrap(address caller, uint24 tokenType, bytes memory param) external returns (uint);

    function unwrap(address caller, uint tokenId, uint amount) external;

    function getValue(uint tokenId, uint amount) external view returns (uint);

    function getValueAsCollateral(address lender, uint _tokenId, uint _amount) external view returns (uint);

    function getValueAsDebt(address lender, uint _tokenId, uint _amount) external view returns (uint);

    function getNextTokenId(address caller, uint24 tokenType) external view returns (uint);
}
