// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';

contract MockERC1155 is ERC1155 {
    constructor() public ERC1155("") {}

    function mint(
        address account,
        uint256 id,
        uint256 amount
    ) public {
        _mint(account, id, amount, "");
    }
}