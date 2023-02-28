// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/IMortgage.sol";
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/IAsset.sol";

contract SyntheticFT is IWrapper, OwnableUpgradeable, ERC1155HolderUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct SynthFT {
        uint256[] underlyingTokens;
        uint256[] underlyingAmounts;
        uint256 totalSupply; // If NFT, Unnecessary gas cost
    }

    mapping(uint256 => SynthFT) public tokenInfos;
    ITokenization public tokenization;
    IAsset public asset;
    uint256 public sequentialN;

    /// @dev Throws if called by not router.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _asset) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        asset = IAsset(_asset);
        sequentialN = 1;
    }

    function wrap(bytes calldata _param) external override onlyTokenization {
        (uint256[] memory tokens, uint256[] memory amounts, uint256 _sequentialN, uint256 mintAmount)
        = abi.decode(_param, (uint256[], uint256[], uint256, uint256));

        asset.safeBatchTransferFrom(tokenization.caller(), address(this), tokens, amounts, '');
        uint tokenId;
        if (_sequentialN == 0) {
            tokenId = tokenization.mintCallback(sequentialN++, mintAmount);
        } else {
            tokenId = tokenization.mintCallback(_sequentialN, mintAmount);
        }

        SynthFT storage ft = tokenInfos[tokenId];
        ft.totalSupply += mintAmount;
        for (uint i = 0; i < tokens.length; i ++) {
            if (ft.underlyingTokens.length <= i) {
                ft.underlyingTokens.push(tokens[i]);
                ft.underlyingAmounts.push(amounts[i]);
            } else {
                require(ft.underlyingTokens[i] == tokens[i], 'Invalid Param');
                ft.underlyingAmounts[i] += amounts[i];
            }
        }
    }

    function unwrap(uint _tokenId, uint _amount) external override onlyTokenization {
        SynthFT memory ft = tokenInfos[_tokenId];
        uint256[] memory amounts = new uint256[](ft.underlyingAmounts.length);
        for (uint i = 0; i < amounts.length; i++) {
            amounts[i] = ft.underlyingAmounts[i] * _amount / ft.totalSupply;
            ft.underlyingAmounts[i] -= amounts[i];
        }
        asset.safeBatchTransferFrom(address(this), tokenization.caller(), ft.underlyingTokens, amounts, '');
        ITokenization(tokenization).burnCallback(_tokenId, _amount);
        ft.totalSupply -= _amount;

        tokenInfos[_tokenId] = ft;
    }

    function getValue(uint _tokenId, uint _amount) public view override returns (uint){
        SynthFT memory token = tokenInfos[_tokenId];
        uint totalValue = 0;
        for (uint i = 0; i < token.underlyingTokens.length; i ++) {
            totalValue += tokenization.getValue(token.underlyingTokens[i], token.underlyingAmounts[i]);
        }
        if (_amount == 0) {
            return totalValue;
        }
        return totalValue * _amount / token.totalSupply;
    }

    function getTokenInfo(uint _tokenId) external view returns (uint[] memory tokens, uint[] memory amounts){
        return (tokenInfos[_tokenId].underlyingTokens, tokenInfos[_tokenId].underlyingAmounts);
    }
}
