pragma solidity ^0.8.12;

interface IERC20Ex {
  function name() external view returns (string memory);

  function owner() external view returns (address);

  function decimals() external view returns (uint);
}
