// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITokenization {
    function wrap(uint24 _wrapperTokenType, bytes calldata param) external;

    function unwrap(uint _tokenId, uint _amount) external;

    function trigger(uint _tokenId, bytes calldata _param) external;

    function getValue(uint tokenId, uint amount) external view returns (uint);

    function caller() external view returns (address);

    /// Callback Functions
    function doTransferIn(uint256 _tokenId, uint256 _amount) external;

    function doTransferInBatch(uint256[] calldata _tokenIds, uint256[] calldata _amounts) external;

    function doTransferOut(address recipient, uint256 _tokenId, uint256 _amount) external;

    function doTransferOutBatch(address recipient, uint256[] calldata _tokenIds, uint256[] calldata _amounts) external;

    function mintCallback(uint256 _sequentialN, uint256 _amount) external returns (uint);

    function burnCallback(uint256 _tokenId, uint256 _amount) external;
}
