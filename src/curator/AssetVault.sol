// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "forge-std/Test.sol";

import "./../interfaces/IRouter.sol";
import "./../interfaces/IDataStore.sol";
import "./../interfaces/IDepositHandler.sol";
import "./../interfaces/IWithdrawHandler.sol";
import "./../DataStore.sol";

contract AssetVault {
    using SafeERC20 for IERC20;
    
    // Vault state
    string public name;
    string public symbol;
    uint8 public decimals;
    address public asset;       
    address public curator;      
    uint256 public totalAssets;  
    uint256 public totalShares;
    bool public initialized;
    
    // User balances
    mapping(address => uint256) public shareBalances;
    
    // APY tracking
    uint256 public currentApy; 
    uint256 public lastApyUpdate;
    
    // Market allocation structure
    struct MarketAllocation {
        address market;
        uint256 allocationPercentage;  // in basis points (10000 = 100%)
        uint256 allocatedAmount;
        bool isActive;
    }
    
    // Markets data
    MarketAllocation[] public markets;
    mapping(address => MarketInfo) public marketInfos;
    mapping(address => uint256) public marketIndexes; // marketAddress => index + 1 (0 means not found)
    
    // Router and handler addresses
    address public immutable router;
    address public immutable dataStore;
    address public immutable depositHandler;
    address public immutable depositVault;
    address public immutable withdrawVault;
    address public immutable marketFactory;
    address public immutable wnt;
    uint256 public depositNonce;

    // Events
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event ApyUpdated(uint256 newApy);
    event MarketAdded(address indexed market, uint256 allocationPercentage);
    event MarketUpdated(address indexed market, uint256 allocationPercentage, bool isActive);
    event Allocated(address indexed market, uint256 amount);
    event Deallocated(address indexed market, uint256 amount);
    event Rebalanced();

    struct MarketInfo {
        uint256 weight;
        bool isActive;
    }

    constructor(
        address _router,
        address _dataStore,
        address _depositHandler,
        address _depositVault,
        address _withdrawVault,
        address _marketFactory,
        address _wnt
    ) {
        router = _router;
        dataStore = _dataStore;
        depositHandler = _depositHandler;
        depositVault = _depositVault;
        marketFactory = _marketFactory;
        withdrawVault = _withdrawVault;
        wnt = _wnt;
        // Approve router to spend WNT for execution fees
        IERC20(_wnt).approve(_router, type(uint256).max);
    }

    modifier onlyInitialized() {
        require(initialized, "Not initialized");
        _;
    }
    
    modifier onlyCurator() {
        require(msg.sender == curator, "Only curator");
        _;
    }

    function initialize(
        address _curator,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external {
        require(!initialized, "Already initialized");
        
        curator = _curator;
        asset = _asset;
        name = _name;
        symbol = _symbol;
        decimals = ERC20(_asset).decimals();
        
        IERC20(_asset).approve(router, type(uint256).max);
        
        initialized = true;
    }

    function getMarketInfo(address _market) external view returns (MarketInfo memory) {
        return marketInfos[_market];
    }

    function deposit(uint256 _amount) external onlyInitialized returns (uint256 shares) {
        require(_amount > 0, "Cannot deposit 0");
        
        // Calculate shares to mint
        shares = totalShares == 0 
            ? _amount 
            : (_amount * totalShares) / totalAssets;
        
        // Transfer assets from user
        IERC20(asset).safeTransferFrom(msg.sender, address(this), _amount);
        
        // Update state
        totalAssets += _amount;
        totalShares += shares;
        shareBalances[msg.sender] += shares;
        
        emit Deposit(msg.sender, _amount, shares);
        
        // Rebalance allocations after deposit
        _rebalanceAllocations();
        
        return shares;
    }

    function withdraw(uint256 _shares) external onlyInitialized returns (uint256 assets) {
        require(_shares > 0, "Cannot withdraw 0");
        require(_shares <= shareBalances[msg.sender], "Insufficient shares");
        
        // Calculate assets to withdraw
        assets = (_shares * totalAssets) / totalShares;
        
        // Ensure we have enough liquidity
        uint256 availableLiquidity = IERC20(asset).balanceOf(address(this));
        if (availableLiquidity < assets) {
            // Need to deallocate from markets
            uint256 amountNeeded = assets - availableLiquidity;
            
            // Deallocate proportionally from active markets
            for (uint256 i = 0; i < markets.length && amountNeeded > 0; i++) {
                if (!markets[i].isActive || markets[i].allocatedAmount == 0) continue;
                
                uint256 amountToWithdraw = Math.min(amountNeeded, markets[i].allocatedAmount);
                _deallocateFromMarket(markets[i].market, amountToWithdraw);
                
                amountNeeded -= amountToWithdraw;
            }
            
            require(
                IERC20(asset).balanceOf(address(this)) >= assets,
                "Insufficient liquidity after deallocations"
            );
        }
        
        // Update state
        totalShares -= _shares;
        totalAssets -= assets;
        shareBalances[msg.sender] -= _shares;
        
        // Transfer assets to user
        IERC20(asset).transfer(msg.sender, assets);
        
        emit Withdraw(msg.sender, assets, _shares);
        
        return assets;
    }

    // Market management functions
    function addMarket(address _market, uint256 _allocationPercentage) external onlyCurator {
        require(_market != address(0), "Invalid market address");
        require(_allocationPercentage <= 10000, "Invalid allocation percentage");
        
        uint256 index = marketIndexes[_market];
        require(index == 0, "Market already exists");
        
        // Add market to array
        markets.push(MarketAllocation({
            market: _market,
            allocationPercentage: _allocationPercentage,
            allocatedAmount: 0,
            isActive: true
        }));
        
        marketIndexes[_market] = markets.length;
        marketInfos[_market] = MarketInfo({
            weight: _allocationPercentage,
            isActive: true
        });

        // Calculate allocation amount
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 allocationAmount = (balance * _allocationPercentage) / 10000;
        
        // Approve market token spending for both deposit and withdrawal
        IERC20(asset).approve(_market, allocationAmount);
        IERC20(_market).approve(router, type(uint256).max);
        
        // Allocate funds if we have balance
        if (allocationAmount > 0) {
            _allocateToMarket(_market, allocationAmount);
        }
        
        emit MarketAdded(_market, _allocationPercentage);
    }

    function updateMarket(
        address _market, 
        uint256 _allocationPercentage, 
        bool _isActive
    ) external onlyCurator onlyInitialized {
        require(_allocationPercentage <= 10000, "Percentage exceeds 100%");
        
        uint256 index = marketIndexes[_market];
        require(index > 0, "Market not found");
        index -= 1;
        
        uint256 oldPercentage = markets[index].allocationPercentage;
        uint256 totalAllocation = getTotalAllocation() - oldPercentage;
        require(totalAllocation + _allocationPercentage <= 10000, "Total allocation exceeds 100%");
        
        markets[index].allocationPercentage = _allocationPercentage;
        markets[index].isActive = _isActive;

        marketInfos[_market] = MarketInfo({
            weight: _allocationPercentage,
            isActive: _isActive
        });
        
        emit MarketUpdated(_market, _allocationPercentage, _isActive);
        
        _rebalanceAllocations();
    }

    // Internal functions
    function _rebalanceAllocations() internal {
        if (totalAssets == 0) return;

        bool hasActiveMarkets = false;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i].isActive) {
                hasActiveMarkets = true;
                break;
            }
        }
        
        if (!hasActiveMarkets) return;
        
        uint256 totalAllocation = getTotalAllocation();
        require(totalAllocation <= 10000, "Total allocation exceeds 100%");
        
        for (uint256 i = 0; i < markets.length; i++) {
            if (!markets[i].isActive) continue;
            
            uint256 targetAllocation = (totalAssets * markets[i].allocationPercentage) / 10000;
            uint256 currentAllocation = markets[i].allocatedAmount;
            
            if (targetAllocation > currentAllocation) {
                uint256 amountToAllocate = targetAllocation - currentAllocation;
                uint256 availableAssets = IERC20(asset).balanceOf(address(this));
                
                if (amountToAllocate <= availableAssets) {
                    _allocateToMarket(markets[i].market, amountToAllocate);
                } else {
                    _allocateToMarket(markets[i].market, availableAssets);
                }
            } else if (targetAllocation < currentAllocation) {
                uint256 amountToDeallocate = currentAllocation - targetAllocation;
                _deallocateFromMarket(markets[i].market, amountToDeallocate);
            }
        }
        
        emit Rebalanced();
    }

    function _allocateToMarket(address _market, uint256 _amount) internal {
        if (_amount == 0) return;

        bytes32 marketKey = IDataStore(dataStore).getMarketKey(_market);
        IMarketFactory.Market memory market = IDataStore(dataStore).getMarket(marketKey);
        
        IERC20(asset).approve(_market, _amount);
        
        bytes[] memory depositData = new bytes[](3);
        
        depositData[0] = abi.encodeCall(
            IRouter.sendWnt,
            (address(depositVault), 1e6)
        );

        depositData[1] = abi.encodeCall(
            IRouter.sendTokens,
            (asset, address(depositVault), _amount)
        );

        depositData[2] = abi.encodeCall(
            IRouter.createDeposit,
            (IDepositHandler.CreateDepositParams({
                receiver: address(this),
                uiFeeReceiver: address(0),
                market: _market,
                initialLongToken: market.longToken,
                initialShortToken: market.shortToken,
                minMarketTokens: 0,
                executionFee: 1e6
            }))
        );

        IRouter(router).multicall(depositData);
        
        uint256 index = marketIndexes[_market];
        markets[index - 1].allocatedAmount += _amount;
        
        emit Allocated(_market, _amount);
    }

    function _deallocateFromMarket(address _market, uint256 _amount) internal {
        if (_amount == 0) return;
        
        uint256 index = marketIndexes[_market];
        require(index > 0, "Market not found");
        index -= 1;
        
        if (_amount > markets[index].allocatedAmount) {
            _amount = markets[index].allocatedAmount;
        }
        
        bytes32 marketKey = IDataStore(dataStore).getMarketKey(_market);
        IMarketFactory.Market memory market = IDataStore(dataStore).getMarket(marketKey);

        uint256 realDeallocateAmount = ERC20(_market).balanceOf(address(this)) * _amount / markets[index].allocatedAmount;

        // Create withdraw params
        bytes[] memory withdrawData = new bytes[](3);
        uint256 executionFee = 1e6;

        // 1. Send execution fee
        withdrawData[0] = abi.encodeWithSelector(
            IRouter.sendWnt.selector,
            address(withdrawVault),
            executionFee
        );

        // 2. Send market tokens
        withdrawData[1] = abi.encodeWithSelector(
            IRouter.sendTokens.selector,
            address(_market),
            address(withdrawVault),
            realDeallocateAmount
        );

        // 3. Create withdraw
        IWithdrawHandler.CreateWithdrawParams memory params = IWithdrawHandler.CreateWithdrawParams({
            receiver: address(this),
            uiFeeReceiver: address(0),
            marketToken: _market,
            longToken: market.longToken,
            shortToken: market.shortToken,
            marketTokenAmount: realDeallocateAmount,
            longTokenAmount: market.longToken == asset ? 100 : 0,
            shortTokenAmount: market.shortToken == asset ? 100 : 0,
            executionFee: executionFee
        });

        withdrawData[2] = abi.encodeWithSelector(
            IRouter.createWithdraw.selector,
            params
        );

        // Execute multicall
        IRouter(router).multicall(withdrawData);
        
        // Update allocated amount
        markets[index].allocatedAmount -= _amount;
        
        emit Deallocated(_market, _amount);
    }

    // View functions
    function getTotalAllocation() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i].isActive) {
                total += markets[i].allocationPercentage;
            }
        }
        return total;
    }

    function getCurrentAllocations() external view returns (
        address[] memory marketsArray,
        uint256[] memory allocations
    ) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i].isActive) activeCount++;
        }
        
        marketsArray = new address[](activeCount);
        allocations = new uint256[](activeCount);
        
        uint256 j = 0;
        for (uint256 i = 0; i < markets.length; i++) {
            if (markets[i].isActive) {
                marketsArray[j] = markets[i].market;
                allocations[j] = markets[i].allocatedAmount;
                j++;
            }
        }
        
        return (marketsArray, allocations);
    }
}
