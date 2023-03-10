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
import "../../../interfaces/ITrigger.sol";
import "../../../interfaces/IAsset.sol";
import "../../connector/library/SafeCastUint256.sol";
import "../../utils/FactorialContext.sol";

contract SyntheticFT is IWrapper, OwnableUpgradeable, ERC1155HolderUpgradeable, FactorialContext {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;
    using SafeCastUint256 for uint256;

    struct SynthFT {
        uint256[] underlyingTokens;
        uint256[] underlyingAmounts;
        uint256 totalSupply; // If NFT, Unnecessary gas cost
    }

    mapping(uint256 => SynthFT) public tokenInfos;
    ITokenization public tokenization;
    uint256 public sequentialN;

    /// @dev Throws if called by not router.
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
        sequentialN = 1;
    }

    /// @dev Wrap multi token to FT.
    /// @param _caller The caller of wrapping. It is same of tokenization module's msg.sender.
    /// @param _tokenType The 24-bit token type.
    /// @param _param The encoded calldata.
    function wrap(
        address _caller,
        uint24 _tokenType,
        bytes calldata _param
    ) external override onlyTokenization returns (uint256 tokenId){
        // 0. Decode parameters
        (uint256[] memory tokens, uint256[] memory amounts, uint256 _sequentialN, uint256 mintAmount)
        = abi.decode(_param, (uint256[], uint256[], uint256, uint256));

        // 1. Get token id
        if (_sequentialN == 0) _sequentialN = sequentialN++;
        tokenId = (uint256(_tokenType) << 232) + (_sequentialN << 160) + uint256(uint160(_caller));

        // 2. Store states
        SynthFT storage ft = tokenInfos[tokenId];
        ft.totalSupply += mintAmount;
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (ft.underlyingTokens.length <= i) {
                ft.underlyingTokens.push(tokens[i]);
                ft.underlyingAmounts.push(amounts[i]);
            } else {
                require(ft.underlyingTokens[i] == tokens[i], 'Invalid Param');
                ft.underlyingAmounts[i] += amounts[i];
            }
        }

        // 3. Mint token to user
        asset.safeBatchTransferFrom(_caller, address(this), tokens, amounts, '');
        asset.mint(_caller, tokenId, mintAmount);

        // 4. Return token id
        return tokenId;
    }

    /// @dev Unwrap FT to multi asset.
    /// @param _caller The caller of unwrapping. It is same of tokenization module's msg.sender.
    /// @param _tokenId The token id to unwrap.
    /// @param _amount The amount of unwrap.
    function unwrap(address _caller, uint256 _tokenId, uint256 _amount) external override onlyTokenization {
        // 0. Calculate portion of underlying asset
        SynthFT memory ft = tokenInfos[_tokenId];
        uint256[] memory amounts = new uint256[](ft.underlyingAmounts.length);
        for (uint256 i = 0; i < amounts.length; ++i) {
            amounts[i] = ft.underlyingAmounts[i] * _amount / ft.totalSupply;
            ft.underlyingAmounts[i] -= amounts[i];
        }
        ft.totalSupply -= _amount;

        // 1. Burn wrapping token & Transfer underlying assets to caller.
        asset.burn(_caller, _tokenId, _amount);
        asset.safeBatchTransferFrom(address(this), _caller, ft.underlyingTokens, amounts, '');

        // 2. Store states
        tokenInfos[_tokenId] = ft;
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Return value of token by id and amount.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued.
    function getValue(uint256 _tokenId, uint256 _amount) public view override returns (uint){
        SynthFT memory token = tokenInfos[_tokenId];
        uint256 totalValue = 0;
        for (uint256 i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValue(token.underlyingTokens[i], token.underlyingAmounts[i]);
        }
        return totalValue * _amount / token.totalSupply;
    }

    /// @dev Return token value as collateral. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address. This is for using custom factor.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued.
    function getValueAsCollateral(
        address _lendingProtocol,
        uint256 _tokenId,
        uint256 _amount
    ) public view override returns (uint) {
        SynthFT memory token = tokenInfos[_tokenId];
        uint256 totalValue = 0;
        for (uint256 i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValueAsCollateral(
                _lendingProtocol,
                token.underlyingTokens[i],
                token.underlyingAmounts[i]
            );
        }
        return totalValue * _amount / token.totalSupply;
    }

    /// @dev Return token value as debt. For debt token wrapper.
    /// @param _lendingProtocol The lending protocol address. This is for using custom factor.
    /// @param _tokenId The token ID to be valued.
    /// @param _amount The amount of token to be valued. If NFT token, it should be 1.
    function getValueAsDebt(
        address _lendingProtocol,
        uint256 _tokenId,
        uint256 _amount
    ) public view override returns (uint) {
        SynthFT memory token = tokenInfos[_tokenId];
        uint256 totalValue = 0;
        for (uint256 i = 0; i < token.underlyingTokens.length; ++i) {
            totalValue += tokenization.getValueAsDebt(
                _lendingProtocol,
                token.underlyingTokens[i],
                token.underlyingAmounts[i]
            );
        }
        return totalValue * _amount / token.totalSupply;
    }

    function getTokenInfo(uint256 _tokenId) external view returns (uint256[] memory tokens, uint256[] memory amounts){
        return (tokenInfos[_tokenId].underlyingTokens, tokenInfos[_tokenId].underlyingAmounts);
    }

    function getNextTokenId(address _caller, uint24 _tokenType) public view override returns (uint) {
        return (uint256(_tokenType) << 232) + (sequentialN << 160) + uint256(uint160(_caller));
    }
}
