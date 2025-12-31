// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title CollateralVault
 * @dev Manages collateral deposits and withdrawals for stablecoin minting
 * @author Garrett Carroll
 */
contract CollateralVault is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    struct CollateralInfo {
        bool isActive;
        uint256 depositedAmount;
        uint256 collateralRatio; // Basis points (15000 = 150%)
        uint256 liquidationThreshold; // Basis points (12000 = 120%)
        address priceFeed;
    }

    struct UserPosition {
        uint256 collateralAmount;
        uint256 mintedAmount;
        uint256 lastUpdateTime;
    }

    // Supported collateral tokens
    mapping(address => CollateralInfo) public supportedCollateral;
    address[] public collateralTokens;

    // User positions: user => collateral token => position
    mapping(address => mapping(address => UserPosition)) public userPositions;

    // Protocol parameters
    uint256 public stabilityFee; // Annual fee in basis points
    uint256 public liquidationPenalty; // Penalty in basis points
    address public stablecoinAddress;
    address public treasuryAddress;

    // Events
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 amount);
    event PositionLiquidated(address indexed user, address indexed token, uint256 collateralSeized, uint256 debtRepaid);
    event CollateralAdded(address indexed token, uint256 collateralRatio, uint256 liquidationThreshold);
    event CollateralUpdated(address indexed token, uint256 collateralRatio, uint256 liquidationThreshold);
    event StabilityFeeUpdated(uint256 newFee);

    constructor(
        address _stablecoin,
        address _treasury,
        uint256 _stabilityFee
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);

        stablecoinAddress = _stablecoin;
        treasuryAddress = _treasury;
        stabilityFee = _stabilityFee;
        liquidationPenalty = 1000; // 10% default
    }

    /**
     * @dev Add new collateral token
     */
    function addCollateral(
        address token,
        uint256 collateralRatio,
        uint256 liquidationThreshold,
        address priceFeed
    ) external onlyRole(MANAGER_ROLE) {
        require(token != address(0), "Invalid token address");
        require(!supportedCollateral[token].isActive, "Collateral already exists");
        require(collateralRatio > liquidationThreshold, "Invalid ratios");
        require(liquidationThreshold >= 10000, "Threshold too low");

        supportedCollateral[token] = CollateralInfo({
            isActive: true,
            depositedAmount: 0,
            collateralRatio: collateralRatio,
            liquidationThreshold: liquidationThreshold,
            priceFeed: priceFeed
        });

        collateralTokens.push(token);
        emit CollateralAdded(token, collateralRatio, liquidationThreshold);
    }

    /**
     * @dev Deposit collateral
     */
    function depositCollateral(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(supportedCollateral[token].isActive, "Collateral not supported");
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        UserPosition storage position = userPositions[msg.sender][token];
        position.collateralAmount += amount;
        position.lastUpdateTime = block.timestamp;

        supportedCollateral[token].depositedAmount += amount;

        emit CollateralDeposited(msg.sender, token, amount);
    }

    /**
     * @dev Withdraw collateral
     */
    function withdrawCollateral(
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        UserPosition storage position = userPositions[msg.sender][token];
        require(position.collateralAmount >= amount, "Insufficient collateral");

        // Check if withdrawal maintains collateral ratio
        uint256 remainingCollateral = position.collateralAmount - amount;
        if (position.mintedAmount > 0) {
            require(
                _checkCollateralRatio(token, remainingCollateral, position.mintedAmount),
                "Would violate collateral ratio"
            );
        }

        position.collateralAmount -= amount;
        position.lastUpdateTime = block.timestamp;
        supportedCollateral[token].depositedAmount -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit CollateralWithdrawn(msg.sender, token, amount);
    }

    /**
     * @dev Record minted stablecoins against collateral
     */
    function recordMint(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        UserPosition storage position = userPositions[user][token];
        require(
            _checkCollateralRatio(token, position.collateralAmount, position.mintedAmount + amount),
            "Insufficient collateral"
        );

        position.mintedAmount += amount;
        position.lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Record burned stablecoins
     */
    function recordBurn(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(MANAGER_ROLE) {
        UserPosition storage position = userPositions[user][token];
        require(position.mintedAmount >= amount, "Burn amount exceeds debt");

        position.mintedAmount -= amount;
        position.lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Liquidate undercollateralized position
     */
    function liquidate(
        address user,
        address token
    ) external onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        UserPosition storage position = userPositions[user][token];
        require(position.collateralAmount > 0, "No collateral");
        require(position.mintedAmount > 0, "No debt");

        require(
            !_checkLiquidationThreshold(token, position.collateralAmount, position.mintedAmount),
            "Position is healthy"
        );

        uint256 penalty = (position.collateralAmount * liquidationPenalty) / 10000;
        uint256 collateralToSeize = position.collateralAmount;
        uint256 debtToRepay = position.mintedAmount;

        // Reset position
        position.collateralAmount = 0;
        position.mintedAmount = 0;
        position.lastUpdateTime = block.timestamp;

        supportedCollateral[token].depositedAmount -= collateralToSeize;

        // Transfer penalty to treasury
        if (penalty > 0) {
            IERC20(token).safeTransfer(treasuryAddress, penalty);
        }

        // Transfer remaining to liquidator
        IERC20(token).safeTransfer(msg.sender, collateralToSeize - penalty);

        emit PositionLiquidated(user, token, collateralToSeize, debtToRepay);
    }

    /**
     * @dev Check if position meets collateral ratio
     */
    function _checkCollateralRatio(
        address token,
        uint256 collateralAmount,
        uint256 mintedAmount
    ) internal view returns (bool) {
        if (mintedAmount == 0) return true;

        CollateralInfo memory info = supportedCollateral[token];
        uint256 requiredCollateral = (mintedAmount * info.collateralRatio) / 10000;
        
        return collateralAmount >= requiredCollateral;
    }

    /**
     * @dev Check if position is above liquidation threshold
     */
    function _checkLiquidationThreshold(
        address token,
        uint256 collateralAmount,
        uint256 mintedAmount
    ) internal view returns (bool) {
        if (mintedAmount == 0) return true;

        CollateralInfo memory info = supportedCollateral[token];
        uint256 thresholdCollateral = (mintedAmount * info.liquidationThreshold) / 10000;
        
        return collateralAmount >= thresholdCollateral;
    }

    /**
     * @dev Get user position health factor
     */
    function getHealthFactor(
        address user,
        address token
    ) external view returns (uint256) {
        UserPosition memory position = userPositions[user][token];
        if (position.mintedAmount == 0) return type(uint256).max;

        return (position.collateralAmount * 10000) / position.mintedAmount;
    }

    /**
     * @dev Update stability fee
     */
    function updateStabilityFee(uint256 newFee) external onlyRole(MANAGER_ROLE) {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        stabilityFee = newFee;
        emit StabilityFeeUpdated(newFee);
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Get total collateral value
     */
    function getTotalCollateralValue() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            if (supportedCollateral[token].isActive) {
                total += supportedCollateral[token].depositedAmount;
            }
        }
        return total;
    }
}