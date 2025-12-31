// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PriceOracle
 * @dev Chainlink price feed integration with fallback mechanisms
 * @author Garrett Carroll
 */
contract PriceOracle is AccessControl {
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    struct PriceFeed {
        AggregatorV3Interface feed;
        uint256 heartbeat; // Maximum acceptable staleness in seconds
        uint8 decimals;
        bool isActive;
    }

    mapping(address => PriceFeed) public priceFeeds;
    mapping(address => uint256) public manualPrices; // Fallback prices
    
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10% max deviation
    
    event PriceFeedAdded(address indexed token, address indexed feed);
    event PriceFeedUpdated(address indexed token, address indexed feed);
    event ManualPriceSet(address indexed token, uint256 price);
    event PriceQueried(address indexed token, uint256 price, uint256 timestamp);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Add Chainlink price feed for token
     */
    function addPriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeat
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(token != address(0), "Invalid token");
        require(feedAddress != address(0), "Invalid feed");
        
        AggregatorV3Interface feed = AggregatorV3Interface(feedAddress);
        uint8 decimals = feed.decimals();

        priceFeeds[token] = PriceFeed({
            feed: feed,
            heartbeat: heartbeat,
            decimals: decimals,
            isActive: true
        });

        emit PriceFeedAdded(token, feedAddress);
    }

    /**
     * @dev Get latest price for token
     * @return price Price with 8 decimals (USD)
     * @return timestamp Last update timestamp
     */
    function getPrice(address token) external view returns (uint256 price, uint256 timestamp) {
        PriceFeed memory priceFeed = priceFeeds[token];
        require(priceFeed.isActive, "Price feed not active");

        try priceFeed.feed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            require(answer > 0, "Invalid price");
            require(block.timestamp - updatedAt <= priceFeed.heartbeat, "Stale price");
            
            // Normalize to 8 decimals
            if (priceFeed.decimals < 8) {
                price = uint256(answer) * (10 ** (8 - priceFeed.decimals));
            } else if (priceFeed.decimals > 8) {
                price = uint256(answer) / (10 ** (priceFeed.decimals - 8));
            } else {
                price = uint256(answer);
            }
            
            timestamp = updatedAt;
            return (price, timestamp);
        } catch {
            // Fallback to manual price if Chainlink fails
            require(manualPrices[token] > 0, "No fallback price available");
            return (manualPrices[token], block.timestamp);
        }
    }

    /**
     * @dev Set manual fallback price
     */
    function setManualPrice(
        address token,
        uint256 price
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(price > 0, "Invalid price");
        manualPrices[token] = price;
        emit ManualPriceSet(token, price);
    }

    /**
     * @dev Update price feed heartbeat
     */
    function updateHeartbeat(
        address token,
        uint256 newHeartbeat
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(priceFeeds[token].isActive, "Price feed not active");
        priceFeeds[token].heartbeat = newHeartbeat;
    }

    /**
     * @dev Deactivate price feed
     */
    function deactivatePriceFeed(
        address token
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        priceFeeds[token].isActive = false;
    }

    /**
     * @dev Reactivate price feed
     */
    function reactivatePriceFeed(
        address token
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(address(priceFeeds[token].feed) != address(0), "Price feed not set");
        priceFeeds[token].isActive = true;
    }

    /**
     * @dev Check if price is fresh
     */
    function isPriceFresh(address token) external view returns (bool) {
        PriceFeed memory priceFeed = priceFeeds[token];
        if (!priceFeed.isActive) return false;

        try priceFeed.feed.latestRoundData() returns (
            uint80,
            int256 answer,
            uint256,
            uint256 updatedAt,
            uint80
        ) {
            return answer > 0 && (block.timestamp - updatedAt <= priceFeed.heartbeat);
        } catch {
            return false;
        }
    }
}