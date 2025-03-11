// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAssetVault {
    // Structs
    struct MarketAllocation {
        address market;
        uint256 allocationPercentage;  // in basis points (10000 = 100%)
        uint256 allocatedAmount;
        bool isActive;
    }

    // Events
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event ApyUpdated(uint256 newApy);
    event MarketAdded(address indexed market, uint256 allocationPercentage);
    event MarketUpdated(address indexed market, uint256 allocationPercentage, bool isActive);
    event Allocated(address indexed market, uint256 amount);
    event Deallocated(address indexed market, uint256 amount);
    event Rebalanced();

    // View Functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function asset() external view returns (address);
    function curator() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function initialized() external view returns (bool);
    function shareBalances(address user) external view returns (uint256);
    function currentApy() external view returns (uint256);
    function lastApyUpdate() external view returns (uint256);
    function markets(uint256 index) external view returns (MarketAllocation memory);
    function marketIndexes(address market) external view returns (uint256);
    function router() external view returns (address);
    function depositHandler() external view returns (address);
    function depositVault() external view returns (address);
    function depositNonce() external view returns (uint256);
    function getTotalAllocation() external view returns (uint256);
    function getCurrentAllocations() external view returns (
        address[] memory marketsArray,
        uint256[] memory allocations
    );

    // State-Changing Functions
    function initialize(
        address _curator,
        address _asset,
        string calldata _name,
        string calldata _symbol
    ) external;

    function deposit(uint256 _amount) external returns (uint256 shares);
    
    function withdraw(uint256 _shares) external returns (uint256 assets);
    
    function addMarket(address _market, uint256 _allocationPercentage) external;
    
    function updateMarket(
        address _market, 
        uint256 _allocationPercentage, 
        bool _isActive
    ) external;
} 