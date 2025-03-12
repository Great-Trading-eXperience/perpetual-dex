// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Router.sol";
import "../src/DataStore.sol";
import "../src/WithdrawVault.sol";
import "../src/WithdrawHandler.sol";
import "../src/MarketHandler.sol";
import "../src/DepositHandler.sol";
import "../src/MarketFactory.sol";
import "../src/Oracle.sol";
import "../src/mocks/MockToken.sol";
import "../src/curator/AssetVault.sol";
import "../src/curator/VaultFactory.sol";
import "../src/curator/CuratorRegistry.sol";

contract VaultTest is Test {
    Router public router;
    DataStore public dataStore;
    WithdrawVault public withdrawVault;
    DepositVault public depositVault;
    WithdrawHandler public withdrawHandler;
    MarketHandler public marketHandler;
    MarketFactory public marketFactory;
    Oracle public oracle;
    MockToken public wnt;
    MockToken public usdc;
    MarketToken public marketToken;
    DepositHandler public depositHandler;
    AssetVault public vault;
    VaultFactory public vaultFactory;
    AssetVault public vaultImplementation;
    CuratorRegistry public registry;

    address public user = address(1);
    address public keeper = address(2);
    address public curator = address(3);

    // Oracle setup constants
    uint256 constant MIN_BLOCK_INTERVAL = 1;
    uint256 constant MAX_BLOCK_INTERVAL = 100;
    uint256 constant MAX_PRICE_AGE = 3600; // 1 hour
    uint256 constant SIGNER_PK = 0x12345;
    address signer;

    function setUp() public {
        // Get signer address from private key
        signer = vm.addr(SIGNER_PK);

        // Deploy tokens
        wnt = new MockToken("Wrapped Native Token", "WNT", 18);
        usdc = new MockToken("USD Coin", "USDC", 6);
        
        // Deploy Oracle with configuration
        oracle = new Oracle(MIN_BLOCK_INTERVAL, MAX_BLOCK_INTERVAL);
        
        // Configure Oracle
        oracle.setSigner(address(wnt), signer, true);
        oracle.setSigner(address(usdc), signer, true);
        oracle.setMinSigners(address(wnt), 1);
        oracle.setMinSigners(address(usdc), 1);
        oracle.setMaxPriceAge(address(wnt), MAX_PRICE_AGE);
        oracle.setMaxPriceAge(address(usdc), MAX_PRICE_AGE);

        // Set prices
        address[] memory tokens = new address[](2);
        tokens[0] = address(wnt);
        tokens[1] = address(usdc);

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](2);

        // WNT price data
        bytes32 wntHash = keccak256(abi.encodePacked(
            address(wnt),
            uint256(3000 * 1e18),
            block.timestamp,
            block.number
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, wntHash);
        signedPrices[0] = Oracle.SignedPrice({
            price: 3000 * 1e18,
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r, s, v)
        });

        // USDC price data
        bytes32 usdcHash = keccak256(abi.encodePacked(
            address(usdc),
            uint256(1 * 1e18),
            block.timestamp,
            block.number
        ));
        (v, r, s) = vm.sign(SIGNER_PK, usdcHash);
        signedPrices[1] = Oracle.SignedPrice({
            price: 1 * 1e18,
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r, s, v)
        });

        oracle.setPrices(tokens, signedPrices);

        // Deploy core contracts
        dataStore = new DataStore();
        depositVault = new DepositVault();
        withdrawVault = new WithdrawVault();
        marketHandler = new MarketHandler(address(dataStore), address(oracle));
        marketFactory = new MarketFactory(address(dataStore));

        // Deploy handlers
        withdrawHandler = new WithdrawHandler(
            address(dataStore),
            address(withdrawVault),
            address(marketHandler),
            address(wnt)
        );

        depositHandler = new DepositHandler(
            address(dataStore),
            address(depositVault),
            address(marketHandler),
            address(wnt)
        );

        // Deploy router
        router = new Router(
            address(dataStore),
            address(depositHandler),
            address(withdrawHandler),
            address(0), // order handler
            address(wnt),
            address(0) // position handler
        );

        // Create market
        bytes32 marketKey = keccak256(abi.encodePacked(address(wnt), address(usdc)));
        address marketTokenAddress = marketFactory.createMarket(address(wnt), address(usdc));
        marketToken = MarketToken(marketTokenAddress);

        // Deploy vault implementation first
        vaultImplementation = new AssetVault(
            address(router),
            address(dataStore),
            address(depositHandler),
            address(depositVault),
            address(withdrawVault),
            address(marketFactory),
            address(wnt)
        );

        // Deploy registry
        registry = new CuratorRegistry();

        // Deploy factory and create vault through it
        vaultFactory = new VaultFactory(
            address(vaultImplementation),
            address(registry),
            address(dataStore),
            address(router),
            address(depositHandler),
            address(depositVault),
            address(withdrawVault)
        );

        // Create vault through factory
        vault = AssetVault(vaultFactory.createVault(
            curator,
            address(usdc),
            "USDC Vault",
            "vUSDC",
            address(marketFactory),
            address(wnt)
        ));

        // Fund accounts
        deal(address(wnt), address(this), 100 ether);
        deal(address(usdc), address(this), 100_000 * 10e6);
        deal(address(usdc), user, 100_000 * 10e6);
        
        // Fund vault with WNT for execution fees
        deal(address(wnt), address(vault), 10 ether);

        // Approvals
        vm.startPrank(user);
        usdc.approve(address(vault), type(uint256).max);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        marketToken.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testAddMarket() public {
        vm.startPrank(curator);
        
        // Add market with 50% allocation
        vault.addMarket(address(marketToken), 5000);
        
        (address[] memory markets, uint256[] memory allocations) = vault.getCurrentAllocations();
        
        assertEq(markets.length, 1);
        assertEq(markets[0], address(marketToken));
        assertEq(vault.getTotalAllocation(), 5000);
        
        vm.stopPrank();
    }

    function testAllocateToMarket() public {
        // First deposit into vault
        vm.startPrank(user);
        uint256 depositAmount = 10_000 * 10**6; // 10,000 USDC
        vault.deposit(depositAmount);
        vm.stopPrank();

        // Add market as curator
        vm.startPrank(curator);
        vault.addMarket(address(marketToken), 5000); // 50% allocation
        vm.stopPrank();

        // Check allocation
        (address[] memory markets, uint256[] memory allocations) = vault.getCurrentAllocations();
        assertEq(allocations[0], 5000 * 10**6); // Should have allocated 5,000 USDC
        
        vm.startPrank(keeper);
        depositHandler.executeDeposit(0);
        vm.stopPrank();

        // Verify market token balance
        uint256 marketTokenBalance = marketToken.balanceOf(address(vault));
        
        assertGt(marketTokenBalance, 0, "Should have received market tokens");
    }

    function testDeallocateFromMarket() public {
        // Setup allocation first
        testAllocateToMarket();
        
        uint256 initialMarketTokenBalance = marketToken.balanceOf(address(vault));
        uint256 initialUsdcBalance = usdc.balanceOf(address(vault));

        // Update market to 25% allocation
        vm.startPrank(curator);
        vault.updateMarket(address(marketToken), 2500, true);
        vm.stopPrank();

        // Execute the withdraw
        vm.startPrank(address(withdrawHandler));
        withdrawHandler.executeWithdraw(0);  // Execute withdraw with key 0
        vm.stopPrank();

        // Verify deallocation
        uint256 finalMarketTokenBalance = marketToken.balanceOf(address(vault));
        uint256 finalUsdcBalance = usdc.balanceOf(address(vault));

        assertLt(finalMarketTokenBalance, initialMarketTokenBalance, "Market token balance should have decreased");
        assertGt(finalUsdcBalance, initialUsdcBalance, "USDC balance should have increased");
        assertLt(finalMarketTokenBalance, initialMarketTokenBalance, "Market token balance should have decreased");
        assertGt(finalUsdcBalance, initialUsdcBalance, "USDC balance should have increased");
        
        (address[] memory markets, uint256[] memory allocations) = vault.getCurrentAllocations();
        assertEq(allocations[0], 2500 * 10**6, "Should have 2,500 USDC allocated");
    }

    function testRebalanceAllocations() public {
        // Initial setup
        vm.startPrank(user);
        uint256 depositAmount = 10_000 * 10**6; // 10,000 USDC
        vault.deposit(depositAmount);
        vm.stopPrank();

        vm.startPrank(curator);
        
        // Add two markets
        vault.addMarket(address(marketToken), 3000); // 30% allocation
        
        // Create second market
        address market2 = marketFactory.createMarket(address(wnt), address(usdc));
        vault.addMarket(market2, 4000); // 40% allocation
        
        vm.stopPrank();

        // Verify allocations
        (address[] memory markets, uint256[] memory allocations) = vault.getCurrentAllocations();
        
        assertEq(markets.length, 2);
        assertEq(allocations[0], 3000 * 10**6); // 3,000 USDC in first market
        assertEq(allocations[1], 4000 * 10**6); // 4,000 USDC in second market
    }
} 