// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAsset {
    function mint(address _to, uint _tokenId, uint _amount) external;

    function burn(address _from, uint _tokenId, uint _amount) external;

    function beforeExecute(uint _maximumLoss) external;

    function afterExecute() external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;
}
