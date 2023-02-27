// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../../interfaces/IWrapper.sol";
import "../../../interfaces/ITokenization.sol";
import "../../../interfaces/IPriceOracle.sol";

contract ERC20Asset is IWrapper, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IPriceOracle public oracle;
    ITokenization public tokenization;

    /// @dev Throws if called by not router.
    modifier onlyTokenization() {
        require(msg.sender == address(tokenization), 'Only tokenization');
        _;
    }

    function initialize(address _oracleRouter, address _tokenization) public initializer {
        __Ownable_init();
        oracle = IPriceOracle(_oracleRouter);
        tokenization = ITokenization(_tokenization);
    }

    function wrap(bytes memory) external pure override {
        revert('Not supported');
    }

    function unwrap(uint, uint) external pure override {
        revert('Not supported');
    }

    function getValue(uint tokenId, uint amount) external view override returns (uint) {
        return oracle.getPrice(address(uint160(tokenId))) * amount;
    }
}
