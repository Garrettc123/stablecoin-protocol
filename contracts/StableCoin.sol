// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title StableCoin
 * @dev Implementation of a USD-pegged stablecoin with upgradeable architecture
 * @author Garrett Carroll
 */
contract StableCoin is 
    Initializable, 
    ERC20Upgradeable, 
    ERC20BurnableUpgradeable, 
    PausableUpgradeable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable 
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BLACKLIST_ROLE = keccak256("BLACKLIST_ROLE");

    mapping(address => bool) private _blacklisted;
    
    uint256 public maxSupply;
    uint256 public mintingFee; // Basis points (100 = 1%)
    uint256 public burningFee; // Basis points
    
    address public feeCollector;
    address public collateralVault;

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event FeesUpdated(uint256 mintingFee, uint256 burningFee);
    event FeeCollectorUpdated(address indexed newFeeCollector);
    event CollateralVaultUpdated(address indexed newVault);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        address _feeCollector
    ) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(BLACKLIST_ROLE, msg.sender);

        maxSupply = _maxSupply;
        feeCollector = _feeCollector;
        mintingFee = 10; // 0.1% default
        burningFee = 10; // 0.1% default
    }

    /**
     * @dev Mint new stablecoins
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        require(!_blacklisted[to], "StableCoin: recipient is blacklisted");
        require(totalSupply() + amount <= maxSupply, "StableCoin: max supply exceeded");
        
        uint256 fee = (amount * mintingFee) / 10000;
        uint256 netAmount = amount - fee;
        
        if (fee > 0) {
            _mint(feeCollector, fee);
        }
        _mint(to, netAmount);
    }

    /**
     * @dev Burn stablecoins with fee
     * @param amount Amount to burn
     */
    function burnWithFee(uint256 amount) public whenNotPaused {
        require(!_blacklisted[msg.sender], "StableCoin: sender is blacklisted");
        
        uint256 fee = (amount * burningFee) / 10000;
        
        if (fee > 0) {
            _transfer(msg.sender, feeCollector, fee);
        }
        
        _burn(msg.sender, amount - fee);
    }

    /**
     * @dev Blacklist an address
     * @param account Address to blacklist
     */
    function blacklist(address account) public onlyRole(BLACKLIST_ROLE) {
        _blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Remove address from blacklist
     * @param account Address to unblacklist
     */
    function unBlacklist(address account) public onlyRole(BLACKLIST_ROLE) {
        _blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    /**
     * @dev Check if address is blacklisted
     */
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklisted[account];
    }

    /**
     * @dev Update minting and burning fees
     * @param _mintingFee New minting fee in basis points
     * @param _burningFee New burning fee in basis points
     */
    function updateFees(uint256 _mintingFee, uint256 _burningFee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_mintingFee <= 500, "StableCoin: minting fee too high"); // Max 5%
        require(_burningFee <= 500, "StableCoin: burning fee too high"); // Max 5%
        
        mintingFee = _mintingFee;
        burningFee = _burningFee;
        
        emit FeesUpdated(_mintingFee, _burningFee);
    }

    /**
     * @dev Update fee collector address
     * @param _feeCollector New fee collector address
     */
    function updateFeeCollector(address _feeCollector) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeCollector != address(0), "StableCoin: zero address");
        feeCollector = _feeCollector;
        emit FeeCollectorUpdated(_feeCollector);
    }

    /**
     * @dev Update collateral vault address
     * @param _vault New vault address
     */
    function updateCollateralVault(address _vault) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_vault != address(0), "StableCoin: zero address");
        collateralVault = _vault;
        emit CollateralVaultUpdated(_vault);
    }

    /**
     * @dev Pause all token transfers
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause all token transfers
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Hook that is called before any transfer of tokens
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual whenNotPaused {
        require(!_blacklisted[from], "StableCoin: sender is blacklisted");
        require(!_blacklisted[to], "StableCoin: recipient is blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Authorize upgrade to new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}