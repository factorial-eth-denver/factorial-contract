// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import "../../interfaces/ITokenization.sol";
import "../../interfaces/IWrapper.sol";
import "../../interfaces/IPriceOracle.sol";

import "../../interfaces/external/IUniswapV2Pair.sol";
import "../../interfaces/external/IMasterChef.sol";

contract SushiswapV2NFT is OwnableUpgradeable, IWrapper {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    struct SushiFarmingNFT {
        uint poolId;
        uint sushiPerShare;
        uint lpAmount;
    }

    mapping(uint256 => SushiFarmingNFT) private tokenInfos;
    ITokenization public tokenization;
    IMasterChef public farm;
    IERC20Upgradeable public sushi;
    uint256 private sequentialN;

    /// @dev Throws if called by not router.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _tokenization, address _farm, address _sushi) public initializer {
        __Ownable_init();
        tokenization = ITokenization(_tokenization);
        farm = IMasterChef(_farm);
        sushi = IERC20Upgradeable(_sushi);
    }

    struct SushiWrapParam {
        uint256 poolId;
        uint256 lpAmount;
    }

    function wrap(bytes calldata param) external override onlyTokenization {
        SushiWrapParam memory param = abi.decode(param, (SushiWrapParam));

        (address lpToken, , ,) = farm.poolInfo(param.poolId);
        ITokenization(tokenization).doTransferIn(uint256(uint160(lpToken)), param.lpAmount);
        farm.deposit(param.poolId, param.lpAmount);
        (, , , uint sushiPerShare) = farm.poolInfo(param.poolId);


        // store states
        uint tokenId = tokenization.mintCallback(sequentialN++, param.lpAmount);
        tokenInfos[tokenId] = SushiFarmingNFT(
            param.poolId,
            sushiPerShare,
            param.lpAmount
        );
    }

    struct UnwrapParam {
        uint256 amount;
    }

    function unwrap(uint _tokenId, uint256 _amount) external override onlyTokenization {
        SushiFarmingNFT memory token = tokenInfos[_tokenId];
        require(token.lpAmount >= _amount, 'Overflow');
        ITokenization(tokenization).burnCallback(_tokenId, _amount);

        farm.withdraw(token.poolId, _amount);
        (address lpToken, , , uint enSushiPerShare) = farm.poolInfo(token.poolId);
        IERC20Upgradeable(lpToken).safeTransfer(msg.sender, _amount);
        // todo check divisiong logic ceiling
        uint stSushi = token.sushiPerShare * _amount / 1e12;
        uint enSushi = enSushiPerShare * _amount / 1e12;
        if (enSushi > stSushi) {
            sushi.safeTransfer(msg.sender, enSushi - stSushi);
        }
        delete tokenInfos[_tokenId];
    }

    function getValue(uint256 tokenId, uint256 amount) public view override returns (uint){
        SushiFarmingNFT memory token = tokenInfos[tokenId];
        (address lpToken, , ,) = farm.poolInfo(token.poolId);
        address token0 = IUniswapV2Pair(lpToken).token0();
        address token1 = IUniswapV2Pair(lpToken).token1();
        uint totalSupply = IUniswapV2Pair(lpToken).totalSupply();
        (uint r0, uint r1,) = IUniswapV2Pair(lpToken).getReserves();
        uint sqrtK = r0 * (r1.sqrt()) * (2 ** 112) / totalSupply;
        uint px0 = tokenization.getValue(uint256(uint160(token0)), 1e18);
        uint px1 = tokenization.getValue(uint256(uint160(token1)), 1e18);
        return sqrtK * 2 * (px0.sqrt()) / (2 ** 56) * (px1.sqrt()) / (2 ** 56) * amount;
    }
}
