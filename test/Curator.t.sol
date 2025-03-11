// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/curator/CurratorRegistry.sol";
import "../src/curator/CurratorFactory.sol";
import "../src/curator/Currator.sol";
import "../src/curator/AssetVault.sol";
import "../src/curator/VaultFactory.sol";
import "../src/Router.sol";
import "../src/DepositHandler.sol";
import "../src/DepositVault.sol";
import "../src/OrderHandler.sol";
import "../src/OrderVault.sol";
import "../src/DataStore.sol";
import "../src/Oracle.sol";
import "../src/MarketFactory.sol";

contract MockToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) 
        ERC20(name_, symbol_) 
    {
        _mint(msg.sender, 1000000 * 10**decimals_);
    }
}

contract MockCurator is Curator {
    constructor() Ownable(msg.sender) {}
}

contract MockLongVault is AssetVault {
    constructor(
        address _router,
        address _depositHandler,
        address _depositVault,
        address _marketFactory
    ) AssetVault(_router, _depositHandler, _depositVault, _marketFactory) {}
}

contract MockShortVault is AssetVault {
    constructor(
        address _router,
        address _depositHandler,
        address _depositVault,
        address _marketFactory
    ) AssetVault(_router, _depositHandler, _depositVault, _marketFactory) {}
}

contract CuratorTest is Test {
    CuratorRegistry public registry;
    CuratorFactory public factory;
    VaultFactory public vaultFactory;
    Curator public curatorImplementation;
    MockToken public weth;
    MockToken public usdc;
    Router public router;
    DepositHandler public depositHandler;
    DepositVault public depositVault;
    OrderHandler public orderHandler;
    OrderVault public orderVault;
    DataStore public dataStore;
    Oracle public oracle;
    MarketFactory public marketFactory;
    
    address public owner = address(1);
    address public curator1 = address(2);
    address public curator2 = address(3);
    address public user = address(4);

    function setUp() public {
        // Deploy mock tokens
        weth = new MockToken("Wrapped ETH", "WETH", 18);
        usdc = new MockToken("USD Coin", "USDC", 6);

        vm.startPrank(owner);  // Start owner context here

        // Deploy core protocol contracts in correct order
        depositVault = new DepositVault();
        orderVault = new OrderVault();
        dataStore = new DataStore();
        dataStore.transferOwnership(owner);
        
        // Deploy Oracle and MarketFactory first
        oracle = new Oracle(1, 100); // min and max block intervals
        marketFactory = new MarketFactory(address(dataStore));

        // Deploy handlers before router
        depositHandler = new DepositHandler(
            address(0),
            address(depositVault),
            address(weth),
            address(dataStore)
        );

        orderHandler = new OrderHandler(
            address(0),
            address(orderVault),
            address(weth),
            address(dataStore),
            address(oracle),
            address(marketFactory)
        );

        // Now deploy router with all addresses
        router = new Router(
            address(weth),
            address(depositHandler),
            address(depositVault),
            address(orderHandler),
            address(orderVault),
            address(dataStore)
        );

        // Update handlers with router address
        depositHandler = new DepositHandler(
            address(router),
            address(depositVault),
            address(weth),
            address(dataStore)
        );

        orderHandler = new OrderHandler(
            address(router),
            address(orderVault),
            address(weth),
            address(dataStore),
            address(oracle),
            address(marketFactory)
        );

        // Deploy curator system contracts
        registry = new CuratorRegistry();
        curatorImplementation = new MockCurator();
        
        factory = new CuratorFactory(
            address(curatorImplementation),
            address(registry)
        );

        // Create mock vault implementations
        MockLongVault vaultImpl = new MockLongVault(
            address(router),
            address(depositHandler),
            address(depositVault),
            address(marketFactory)
        );
        vaultFactory = new VaultFactory(
            address(vaultImpl),
            address(registry),
            address(router),
            address(depositHandler),
            address(depositVault)
        );

        // Setup initial state
        registry.addCurator(curator1, "Curator One", "ipfs://curator1");
        registry.addCurator(curator2, "Curator Two", "ipfs://curator2");
        vm.stopPrank();  // End owner context

        // Fund accounts
        deal(address(weth), user, 100 ether);
        deal(address(usdc), user, 100_000 * 10**6);
    }

    function testDeployCuratorContract() public {
        vm.startPrank(curator1);
        
        address curatorContract = factory.deployCuratorContract(
            "Test Curator",
            "ipfs://test",
            500 // 5% fee
        );
        
        Curator curator = Curator(curatorContract);
        assertEq(curator.name(), "Test Curator");
        assertEq(curator.feePercentage(), 500);
        assertEq(curator.owner(), curator1);
        
        vm.stopPrank();
    }

    function testCreateVault() public {
        vm.startPrank(curator1);
        address curatorContract = factory.deployCuratorContract(
            "Test Curator",
            "ipfs://test",
            500
        );

        // Create short vault
        address vault = vaultFactory.createVault(
            curatorContract,
            address(usdc),
            "USDC Vault",
            "vUSDC",
            address(marketFactory)
        );
        
        AssetVault shortVault = AssetVault(vault);
        assertEq(shortVault.asset(), address(usdc));
        assertEq(shortVault.curator(), curatorContract);
        
        vm.stopPrank();
    }

    function testVaultDeposit() public {
        // Setup vault
        vm.startPrank(curator1);
        address curatorContract = factory.deployCuratorContract(
            "Test Curator",
            "ipfs://test",
            500
        );
        address vault = vaultFactory.createVault(
            curatorContract,
            address(weth),
            "WETH Vault",
            "vWETH",
            address(marketFactory)
        );
        vm.stopPrank();

        // User deposits
        vm.startPrank(user);
        uint256 depositAmount = 10 ether;
        weth.approve(vault, depositAmount);
        
        AssetVault assetVault = AssetVault(vault);
        uint256 shares = assetVault.deposit(depositAmount);
        
        assertEq(assetVault.totalAssets(), depositAmount);
        assertEq(assetVault.totalShares(), shares);
        assertEq(assetVault.shareBalances(user), shares);
        
        vm.stopPrank();
    }

    function testVaultWithdraw() public {
        // Setup vault and deposit
        vm.startPrank(curator1);
        address curatorContract = factory.deployCuratorContract(
            "Test Curator",
            "ipfs://test",
            500
        );
        address vault = vaultFactory.createVault(
            curatorContract,
            address(weth),
            "WETH Vault",
            "vWETH",
            address(marketFactory)
        );
        vm.stopPrank();

        vm.startPrank(user);
        uint256 depositAmount = 10 ether;
        weth.approve(vault, depositAmount);
        
        AssetVault assetVault = AssetVault(vault);
        uint256 shares = assetVault.deposit(depositAmount);

        // Withdraw half
        uint256 withdrawShares = shares / 2;
        uint256 withdrawnAssets = assetVault.withdraw(withdrawShares);
        
        assertEq(assetVault.totalShares(), shares - withdrawShares);
        assertEq(assetVault.shareBalances(user), shares - withdrawShares);
        assertEq(withdrawnAssets, depositAmount / 2);
        
        vm.stopPrank();
    }
}
