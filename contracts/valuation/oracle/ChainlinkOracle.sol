pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../../../interfaces/IPriceOracle.sol";
import "../../../interfaces/IERC20Ex.sol";

contract ChainlinkOracle is IPriceOracle, OwnableUpgradeable {
    mapping(address => address) public priceFeeds; // Mapping from token to price feed

    function initialize() external initializer {
        __Ownable_init();
    }
    /// ----- ADMIN FUNCTIONS -----
    function setPriceFeed(address[] calldata _tokens, address[] calldata _feeds) external onlyOwner {
        require(_tokens.length == _feeds.length, 'tokens & refs length mismatched');
        for (uint256 idx = 0; idx < _tokens.length; idx++) {
            priceFeeds[_tokens[idx]] = _feeds[idx];
        }
    }

    /// ----- VIEW FUNCTIONS -----
    /// @dev Get token price using oracle.
    /// @param _token Token address to get price.
    function getPrice(address _token) external view returns (uint256 price) {
        uint256 decimals = uint(IERC20Ex(_token).decimals());
        (, int answer, , ,) = AggregatorV3Interface(priceFeeds[_token]).latestRoundData();
        return uint(answer) / (10 ** (18 - decimals));
    }
}
