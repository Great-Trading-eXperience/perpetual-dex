// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/DepositHandler.sol";
import "../src/DepositVault.sol";
import "../src/DataStore.sol";
import "../src/MarketFactory.sol";
import "../src/MarketHandler.sol";
import "../src/Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Router.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Update token names
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DepositTest is Test {
    DepositHandler public depositHandler;
    DepositVault public depositVault;
    DataStore public dataStore;
    MarketFactory public marketFactory;
    MarketHandler public marketHandler;
    Oracle public oracle;
    Router public router;
    
    address public wnt;
    address public longToken;
    address public shortToken;
    address public marketToken;
    address public user;
    address public keeper;

    uint256 constant EXECUTION_FEE = 0.01 ether;
    uint256 constant INITIAL_BALANCE = 10000 ether;

    // Constants for Oracle setup
    uint256 constant MIN_BLOCK_INTERVAL = 1;
    uint256 constant MAX_BLOCK_INTERVAL = 100;
    uint256 constant MAX_PRICE_AGE = 3600; // 1 hour

    // Add private key constant
    uint256 constant SIGNER_PK = 0x12345; // Use any private key value
    address signer;

    function setUp() public {
        // Get signer address from private key
        signer = vm.addr(SIGNER_PK);
        
        // Deploy mock tokens with proper names
        MockWETH weth = new MockWETH();
        MockUSDC usdc = new MockUSDC();
        MockToken wbtc = new MockToken();
        wnt = address(weth);
        longToken = address(wbtc);    // WETH as long token
        shortToken = address(usdc);   // USDC as short token
        
        // Setup test accounts
        user = makeAddr("user");
        keeper = msg.sender;
        
        // Deploy Oracle first
        oracle = new Oracle(MIN_BLOCK_INTERVAL, MAX_BLOCK_INTERVAL);
        
        // Configure Oracle with signer address
        oracle.setSigner(longToken, signer, true);
        oracle.setSigner(shortToken, signer, true);
        oracle.setSigner(wnt, signer, true);
        oracle.setMinSigners(longToken, 1);
        oracle.setMinSigners(shortToken, 1);
        oracle.setMinSigners(wnt, 1);
        oracle.setMaxPriceAge(longToken, MAX_PRICE_AGE);
        oracle.setMaxPriceAge(shortToken, MAX_PRICE_AGE);
        oracle.setMaxPriceAge(wnt, MAX_PRICE_AGE);

        // Set initial prices (3000 USDC per 1 WETH)
        address[] memory tokens = new address[](3);
        tokens[0] = longToken;  // WETH
        tokens[1] = shortToken; // USDC
        tokens[2] = wnt;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](3);
        
        uint256 wethPrice = 3000 * 10 ** 18;
        uint256 usdcPrice = 1 * 10 ** 18;
        uint256 wntPrice = 3000 * 10 ** 18;

        // Sign and set price for WETH using the correct private key
        bytes32 wethMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(longToken, wethPrice, block.timestamp, block.number + 1))
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(SIGNER_PK, wethMessageHash);
        signedPrices[0] = Oracle.SignedPrice({
            price: wethPrice,  // WETH price in USDC
            timestamp: block.timestamp,
            blockNumber: block.number + 1,
            signature: abi.encodePacked(r1, s1, v1)
        });

        // Sign and set price for USDC using the correct private key
        bytes32 usdcMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(shortToken, usdcPrice, block.timestamp, block.number + 1))
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(SIGNER_PK, usdcMessageHash);
        signedPrices[1] = Oracle.SignedPrice({
            price: usdcPrice,  // USDC price (1 USD)
            timestamp: block.timestamp,
            blockNumber: block.number + 1,
            signature: abi.encodePacked(r2, s2, v2)
        });

        // Sign and set price for WNT using the correct private key
        bytes32 wntMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(wnt, wntPrice, block.timestamp, block.number + 1))
            )
        );
        (uint8 v3, bytes32 r3, bytes32 s3) = vm.sign(SIGNER_PK, wntMessageHash);
        signedPrices[2] = Oracle.SignedPrice({
            price: wntPrice,  // USDC price (1 USD)
            timestamp: block.timestamp,
            blockNumber: block.number + 1,
            signature: abi.encodePacked(r3, s3, v3)
        });


        vm.roll(block.number + 1);
        oracle.setPrices(tokens, signedPrices);
        
        // Deploy other contracts
        dataStore = new DataStore();
        depositVault = new DepositVault();
        marketFactory = new MarketFactory(address(dataStore));
        marketHandler = new MarketHandler(address(dataStore), address(oracle));
        depositHandler = new DepositHandler(
            address(dataStore),
            address(depositVault),
            address(marketHandler),
            wnt
        );

        // Create market
        marketToken = marketFactory.createMarket(longToken, shortToken);
        
        // First mint tokens to this contract
        MockWETH(longToken).mint(address(this), INITIAL_BALANCE);
        MockUSDC(shortToken).mint(address(this), INITIAL_BALANCE);
        MockToken(wnt).mint(address(this), INITIAL_BALANCE * 4);

        // Approve transfers to user
        IERC20(longToken).approve(user, type(uint256).max);
        IERC20(shortToken).approve(user, type(uint256).max);
        IERC20(wnt).approve(user, type(uint256).max);

        // Fund test accounts with realistic amounts
        vm.deal(user, INITIAL_BALANCE);  // ETH for gas
        IERC20(longToken).transfer(user, 1 * 10**18);    // 100 WETH
        IERC20(shortToken).transfer(user, 3000 * 10**18); // 300,000 USDC
        IERC20(wnt).transfer(user, INITIAL_BALANCE * 2);         // WNT for execution fee
        
        // Deploy Router after other contracts
        router = new Router(
            address(dataStore),
            address(depositHandler),
            address(0), // withdrawHandler (not needed for this test)
            address(0), // orderHandler (not needed for this test)
            wnt
        );
        
        // Update approvals to use router instead of vault
        vm.startPrank(user);
        IERC20(longToken).approve(address(router), type(uint256).max);
        IERC20(shortToken).approve(address(router), type(uint256).max);
        IERC20(wnt).approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Log initial balances for debugging
        console.log("User WETH balance:", IERC20(longToken).balanceOf(user) / 1e18);
        console.log("User USDC balance:", IERC20(shortToken).balanceOf(user) / 1e18);
        console.log("User WNT balance:", IERC20(wnt).balanceOf(user) / 1e18);
    }

    function testCreateDeposit() public {
        vm.startPrank(user);
        
        // Create deposit params
        DepositHandler.CreateDepositParams memory params = DepositHandler.CreateDepositParams({
            receiver: user,
            uiFeeReceiver: address(0),
            market: marketToken,
            initialLongToken: longToken,
            initialShortToken: shortToken,
            minMarketTokens: 0,
            executionFee: EXECUTION_FEE
        });

        // Record balances before
        uint256 longBalanceBefore = IERC20(longToken).balanceOf(user);
        uint256 shortBalanceBefore = IERC20(shortToken).balanceOf(user);

        // Prepare multicall data
        bytes[] memory data = new bytes[](4);
        
        // 1. Transfer WNT for execution fee
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (address(depositVault), EXECUTION_FEE)
        );

        // 2. Transfer long token
        data[1] = abi.encodeCall(
            Router.sendTokens,
            (longToken, address(depositVault), 1 * 10**18) // 1 WETH
        );

        // 3. Transfer short token
        data[2] = abi.encodeCall(
            Router.sendTokens,
            (shortToken, address(depositVault), 3000 * 10**18) // 3000 USDC
        );

        // 4. Create deposit
        data[3] = abi.encodeCall(
            Router.createDeposit,
            (params)
        );

        // Execute multicall
        router.multicall(data);

        // Verify deposit was created
        uint256 depositKey = 0; // First deposit should have key 0
        DepositHandler.Deposit memory deposit = DataStore(dataStore).getDeposit(depositKey);
        
        assertEq(deposit.account, user);
        assertEq(deposit.receiver, user);
        assertEq(deposit.marketToken, marketToken);
        assertEq(deposit.initialLongToken, longToken);
        assertEq(deposit.initialShortToken, shortToken);
        assertEq(deposit.executionFee, EXECUTION_FEE);
        
        // Verify tokens were transferred
        assertLt(IERC20(longToken).balanceOf(user), longBalanceBefore);
        assertLt(IERC20(shortToken).balanceOf(user), shortBalanceBefore);
        
        vm.stopPrank();
    }

    function testExecuteDeposit() public {
        // First create a deposit
        testCreateDeposit();
        
        uint256 depositKey = 0;
        DepositHandler.Deposit memory depositBefore = DataStore(dataStore).getDeposit(depositKey);
        
        // Record balances before execution
        uint256 keeperBalanceBefore = keeper.balance;
        uint256 marketTokenLongBefore = IERC20(longToken).balanceOf(marketToken);
        uint256 marketTokenShortBefore = IERC20(shortToken).balanceOf(marketToken);
        uint256 userMarketTokenBefore = IERC20(marketToken).balanceOf(user);
        
        vm.prank(keeper);
        depositHandler.executeDeposit(depositKey);
        
        // Verify deposit was cleared
        DepositHandler.Deposit memory depositAfter = DataStore(dataStore).getDeposit(depositKey);
        assertEq(depositAfter.account, address(0));
        
        // Verify tokens were transferred to market
        assertEq(
            IERC20(longToken).balanceOf(marketToken),
            marketTokenLongBefore + depositBefore.initialLongTokenAmount
        );
        assertEq(
            IERC20(shortToken).balanceOf(marketToken),
            marketTokenShortBefore + depositBefore.initialShortTokenAmount
        );
        
        // Verify user received market tokens
        assertGt(IERC20(marketToken).balanceOf(user), userMarketTokenBefore);
        
        // Verify keeper received execution fee
        assertApproxEqRel(keeper.balance, keeperBalanceBefore + depositBefore.executionFee, 0.000001 ether);
    }

    function testCancelDeposit() public {
        // First create a deposit
        testCreateDeposit();
        
        uint256 depositKey = 0;
        DepositHandler.Deposit memory depositBefore = DataStore(dataStore).getDeposit(depositKey);
        
        // Record balances before cancellation
        uint256 userLongBefore = IERC20(longToken).balanceOf(user);
        uint256 userShortBefore = IERC20(shortToken).balanceOf(user);
        uint256 userWntBefore = IERC20(wnt).balanceOf(user);
        
        vm.prank(user);
        router.cancelDeposit(depositKey);
        
        // Verify deposit was cleared
        DepositHandler.Deposit memory depositAfter = DataStore(dataStore).getDeposit(depositKey);
        assertEq(depositAfter.account, address(0));
        
        // Verify tokens were returned to user
        assertEq(
            IERC20(longToken).balanceOf(user),
            userLongBefore + depositBefore.initialLongTokenAmount
        );
        assertEq(
            IERC20(shortToken).balanceOf(user),
            userShortBefore + depositBefore.initialShortTokenAmount
        );
        assertEq(
            IERC20(wnt).balanceOf(user),
            userWntBefore + depositBefore.executionFee
        );
    }

    function testCreateDepositWithWNTAsLong() public {
        // Deploy a new market with WNT as long token
        address wntMarket = marketFactory.createMarket(wnt, shortToken);
        
        vm.startPrank(user);
        
        // Create deposit params
        DepositHandler.CreateDepositParams memory params = DepositHandler.CreateDepositParams({
            receiver: user,
            uiFeeReceiver: address(0),
            market: wntMarket,
            initialLongToken: wnt,
            initialShortToken: shortToken,
            minMarketTokens: 0,
            executionFee: EXECUTION_FEE
        });

        // Record balances before
        uint256 wntBalanceBefore = IERC20(wnt).balanceOf(user);
        uint256 shortBalanceBefore = IERC20(shortToken).balanceOf(user);

        // Prepare multicall data
        bytes[] memory data = new bytes[](4);
        
        // 1. Transfer WNT for execution fee
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (address(depositVault), EXECUTION_FEE)
        );

        // 2. Transfer WNT as long token (1 WNT)
        data[1] = abi.encodeCall(
            Router.sendWnt,
            (address(depositVault), 1 * 10**18)
        );

        // 3. Transfer short token (3000 USDC for 1 WNT)
        data[2] = abi.encodeCall(
            Router.sendTokens,
            (shortToken, address(depositVault), 3000 * 10**18)
        );

        // 4. Create deposit
        data[3] = abi.encodeCall(
            Router.createDeposit,
            (params)
        );

        // Execute multicall
        router.multicall(data);

        // Verify deposit was created
        uint256 depositKey = 0; // Second deposit should have key 1
        DepositHandler.Deposit memory deposit = DataStore(dataStore).getDeposit(depositKey);
        
        assertEq(deposit.account, user);
        assertEq(deposit.receiver, user);
        assertEq(deposit.marketToken, wntMarket);
        assertEq(deposit.initialLongToken, wnt);
        assertEq(deposit.initialShortToken, shortToken);
        assertEq(deposit.executionFee, EXECUTION_FEE);
        assertEq(deposit.initialLongTokenAmount, 1 * 10**18);
        assertEq(deposit.initialShortTokenAmount, 3000 * 10**18);
        
        // Verify tokens were transferred
        assertEq(
            IERC20(wnt).balanceOf(user),
            wntBalanceBefore - EXECUTION_FEE - (1 * 10**18), // Both execution fee and long token amount
            "WNT balance incorrect"
        );
        assertEq(
            IERC20(shortToken).balanceOf(user),
            shortBalanceBefore - (3000 * 10**18),
            "Short token balance incorrect"
        );
        
        vm.stopPrank();

        // Test execution
        uint256 keeperBalanceBefore = keeper.balance;
        uint256 marketWntBefore = IERC20(wnt).balanceOf(wntMarket);
        uint256 marketShortBefore = IERC20(shortToken).balanceOf(wntMarket);
        uint256 userMarketTokenBefore = IERC20(wntMarket).balanceOf(user);
        
        vm.prank(keeper);
        depositHandler.executeDeposit(depositKey);
        
        // Verify deposit was cleared
        DepositHandler.Deposit memory depositAfter = DataStore(dataStore).getDeposit(depositKey);
        assertEq(depositAfter.account, address(0));
        
        // Verify tokens were transferred to market
        assertEq(
            IERC20(wnt).balanceOf(wntMarket),
            marketWntBefore + deposit.initialLongTokenAmount
        );
        assertEq(
            IERC20(shortToken).balanceOf(wntMarket),
            marketShortBefore + deposit.initialShortTokenAmount
        );
        
        // Verify user received market tokens
        assertGt(IERC20(wntMarket).balanceOf(user), userMarketTokenBefore);
        
        // Verify keeper received execution fee
        assertApproxEqRel(keeper.balance, keeperBalanceBefore + deposit.executionFee, 0.000001 ether);
    }
} 