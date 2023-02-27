// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/IMortgage.sol";
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/IAsset.sol";

contract SyntheticNFT is OwnableUpgradeable, IWrapper, ERC1155HolderUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct SynthNFT {
        uint256[] underlyingTokens;
        uint256[] underlyingAmounts;
    }

    mapping(uint256 => SynthNFT) private tokenInfos;
    ITokenization public tokenization;
    IAsset public asset;
    uint256 public sequentialN;

    /// @dev Throws if called by not valuation module.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _asset) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        asset = IAsset(_asset);
    }

    struct WrapParam {
        uint256[] tokens;
        uint256[] amounts;
    }

    function wrap(bytes calldata _param) external override onlyTokenization {
        (uint256[] memory tokens, uint256[] memory amounts) = abi.decode(_param, (uint256[], uint256[]));

        asset.safeBatchTransferFrom(tokenization.caller(), address(this), tokens, amounts, '');
        uint tokenId = tokenization.mintCallback(sequentialN++, 1);

        SynthNFT storage token = tokenInfos[tokenId];

        for (uint i = 0; i < tokens.length; i ++) {
            token.underlyingTokens.push(tokens[i]);
            token.underlyingAmounts.push(amounts[i]);
        }
    }

    function unwrap(uint _tokenId, uint) external override onlyTokenization {
        SynthNFT memory nft = tokenInfos[_tokenId];
        asset.safeBatchTransferFrom(address(this), tokenization.caller(), nft.underlyingTokens, nft.underlyingAmounts, '');
        ITokenization(tokenization).burnCallback(_tokenId, 1);
        delete tokenInfos[_tokenId];
    }

    function getValue(uint _tokenId, uint) public view override returns (uint){
        SynthNFT memory token = tokenInfos[_tokenId];
        uint totalValue = 0;
        for (uint i = 0; i < token.underlyingTokens.length; i ++) {
            totalValue += tokenization.getValue(token.underlyingTokens[i], token.underlyingAmounts[i]);
        }
        return totalValue;
    }

    function getTokenInfo(uint _tokenId) external view returns (uint[] memory tokens, uint[] memory amounts){
        return (tokenInfos[_tokenId].underlyingTokens, tokenInfos[_tokenId].underlyingAmounts);
    }
}