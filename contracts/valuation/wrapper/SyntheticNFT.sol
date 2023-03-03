// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../connector/library/SafeCastUint256.sol";

import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/IAsset.sol";

import "../../utils/FactorialContext.sol";
import "hardhat/console.sol";


contract SyntheticNFT is OwnableUpgradeable, IWrapper, ERC1155HolderUpgradeable, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;
    using SafeCastUint256 for uint256;

    struct SynthNFT {
        uint256[] underlyingTokens;
        uint256[] underlyingAmounts;
    }

    mapping(uint256 => SynthNFT) private tokenInfos;
    ITokenization public tokenization;
    uint256 public sequentialN;

    /// @dev Throws if called by not valuation module.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    /// @dev Initialize Synthetic FT contract
    /// @param _tokenization The factorial tokenization module address.
    /// @param _asset The factorial asset management module address
    function initialize(address _tokenization, address _asset) public initializer initContext(_asset) {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
    }


    /// ----- EXTERNAL FUNCTIONS -----
    /// @dev Wrap multi token to NFT.
    /// @param _caller The caller of wrapping. It is same of tokenization module's msg.sender.
    /// @param _tokenType The 24-bit token type.
    /// @param _param The encoded calldata.
    function wrap(
        address _caller,
        uint24 _tokenType,
        bytes calldata _param
    ) external override onlyTokenization returns (uint){
        (uint256[] memory tokens, uint256[] memory amounts) = abi.decode(_param, (uint256[], uint256[]));

        uint tokenId = (uint256(_tokenType) << 232) + (sequentialN++ << 160) + uint256(uint160(_caller));

        // Store states
        SynthNFT storage token = tokenInfos[tokenId];
        token.underlyingTokens = tokens;
        token.underlyingAmounts = amounts;

        // Mint token to user
        asset.safeBatchTransferFrom(_caller, address(this), tokens, amounts, '');
        asset.mint(_caller, tokenId, 1);

        return tokenId;
    }

    /// @dev Unwrap NFT to multi asset.
    /// @param _caller The caller of unwrapping. It is same of tokenization module's msg.sender.
    /// @param _tokenId The token id to unwrap.
    function unwrap(address _caller, uint _tokenId, uint) external override onlyTokenization {
        SynthNFT memory nft = tokenInfos[_tokenId];
        asset.safeBatchTransferFrom(address(this), _caller, nft.underlyingTokens, nft.underlyingAmounts, '');
        asset.burn(_caller, _tokenId, 1);
        delete tokenInfos[_tokenId];
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Return value of token by id and amount.
    /// @param _tokenId The token ID to be valued.
    function getValue(uint _tokenId, uint) public view override returns (uint){
        SynthNFT memory token = tokenInfos[_tokenId];
        uint totalValue = 0;
        for (uint i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValue(token.underlyingTokens[i], token.underlyingAmounts[i]);
        }
        return totalValue;
    }

    /// @dev Return token value as collateral. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address for using custom factor.
    /// @param _tokenId The token ID to be valued.
    function getValueAsCollateral(address _lendingProtocol, uint _tokenId, uint) public view override returns (uint) {
        SynthNFT memory token = tokenInfos[_tokenId];
        uint totalValue = 0;
        for (uint i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValueAsCollateral(
                _lendingProtocol,
                token.underlyingTokens[i],
                token.underlyingAmounts[i]
            );
        }
        return totalValue;
    }

    /// @dev Return token value as debt. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address for using custom factor.
    /// @param _tokenId The token ID to be valued.
    function getValueAsDebt(address _lendingProtocol, uint _tokenId, uint) public view override returns (uint) {
        SynthNFT memory token = tokenInfos[_tokenId];
        uint totalValue = 0;
        for (uint i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValueAsDebt(
                _lendingProtocol,
                token.underlyingTokens[i],
                token.underlyingAmounts[i]
            );
        }
        return totalValue;
    }

    function getTokenInfo(uint _tokenId) external view returns (uint[] memory tokens, uint[] memory amounts){
        return (tokenInfos[_tokenId].underlyingTokens, tokenInfos[_tokenId].underlyingAmounts);
    }

    function getNextTokenId(address _caller, uint24 _tokenType) public view override returns (uint) {
        return (uint256(_tokenType) << 232) + (sequentialN << 160) + uint256(uint160(_caller));
    }
}
