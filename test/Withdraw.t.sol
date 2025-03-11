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
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WithdrawTest is Test {
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

    address public user = address(1);
    address public keeper = address(2);

    // Add constants for Oracle setup
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
        
        // Deploy Oracle first with proper configuration
        oracle = new Oracle(MIN_BLOCK_INTERVAL, MAX_BLOCK_INTERVAL);
        
        // Configure Oracle
        oracle.setSigner(address(wnt), signer, true);
        oracle.setSigner(address(usdc), signer, true);
        oracle.setMinSigners(address(wnt), 1);
        oracle.setMinSigners(address(usdc), 1);
        oracle.setMaxPriceAge(address(wnt), MAX_PRICE_AGE);
        oracle.setMaxPriceAge(address(usdc), MAX_PRICE_AGE);

        // Set prices using setPrices
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

        // Deploy other contracts
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

        // Deploy deposit handler
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

        // Setup market through MarketFactory instead of direct deployment
        bytes32 marketKey = keccak256(abi.encodePacked(address(wnt), address(usdc)));
        address marketTokenAddress = marketFactory.createMarket(address(wnt), address(usdc));
        marketToken = MarketToken(marketTokenAddress);
        
        // Fund user with only WNT and USDC (remove market token funding)
        deal(address(wnt), user, 100 ether);
        deal(address(usdc), user, 100_000 * 10**6);

        // Set approvals for both router and WithdrawVault
        vm.startPrank(user);
        // Router approvals
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        marketToken.approve(address(router), type(uint256).max);
        
        // Deposit and WithdrawVault approvals
        wnt.approve(address(depositVault), type(uint256).max);
        usdc.approve(address(depositVault), type(uint256).max);
        marketToken.approve(address(withdrawVault), type(uint256).max);

        vm.stopPrank();

        vm.label(address(wnt), "WNT");
        vm.label(address(usdc), "USDC");
        vm.label(address(marketToken), "MKT");
        vm.label(user, "User");
        vm.label(keeper, "Keeper");
    }

    function testCreateWithdraw() public {
        // First create and execute a deposit to get market tokens
        vm.startPrank(user);
        
        uint256 longTokenAmount = 10 * 1e18;
        uint256 shortTokenAmount = 20_000 * 1e6;
        uint256 depositExecutionFee = 0.1 ether;

        // Create deposit params
        bytes[] memory depositData = new bytes[](3);

        uint256 longTokenValueUsd = (longTokenAmount * 3000 * 1e18) / (10 ** IERC20Metadata(address(wnt)).decimals());
        uint256 shortTokenValueUsd = (shortTokenAmount * 1 * 1e18) / (10 ** IERC20Metadata(address(usdc)).decimals());
    
        // Send WNT to router
        depositData[0] = abi.encodeWithSelector(
            Router.sendWnt.selector,
            address(depositVault),
            longTokenAmount + depositExecutionFee
        );

        // Send USDC to router 
        depositData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(usdc),
            address(depositVault), 
            shortTokenAmount
        );

        // Create deposit
        DepositHandler.CreateDepositParams memory depositParams = DepositHandler.CreateDepositParams({
            receiver: user,
            uiFeeReceiver: address(0),
            market: address(marketToken),
            initialLongToken: address(wnt),
            initialShortToken: address(usdc),
            minMarketTokens: 0,
            executionFee: depositExecutionFee
        });

        depositData[2] = abi.encodeWithSelector(
            Router.createDeposit.selector,
            depositParams
        );

        router.multicall(depositData);
        
        vm.stopPrank();
        
        // Execute deposit as keeper
        vm.prank(keeper);
        depositHandler.executeDeposit(0);
        
        // Now create withdraw
        vm.startPrank(user);

        uint256 marketTokenBalance = marketToken.balanceOf(user);
        uint256 withdrawAmount = marketTokenBalance / 2;
        uint256 executionFee = 0.1 ether;

        // Create withdraw params
        bytes[] memory withdrawData = new bytes[](3);

        // Send execution fee
        withdrawData[0] = abi.encodeWithSelector(
            Router.sendWnt.selector,
            address(withdrawVault),
            executionFee
        );

        // Send market tokens
        withdrawData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(marketToken),
            address(withdrawVault),
            withdrawAmount
        );

        // Create withdraw
        WithdrawHandler.CreateWithdrawParams memory params = WithdrawHandler.CreateWithdrawParams({
            receiver: user,
            uiFeeReceiver: address(0),
            marketToken: address(marketToken),
            longToken: address(wnt),
            shortToken: address(usdc),
            marketTokenAmount: withdrawAmount,
            longTokenAmount: 50,
            shortTokenAmount: 50,
            executionFee: executionFee
        });

        withdrawData[2] = abi.encodeWithSelector(
            Router.createWithdraw.selector,
            params
        );

        uint256 withdrawKey = abi.decode(router.multicall(withdrawData)[2], (uint256));

        WithdrawHandler.Withdraw memory withdraw = dataStore.getWithdraw(withdrawKey);
        assertEq(withdraw.account, user);
        assertEq(withdraw.marketTokenAmount, withdrawAmount);
        assertEq(withdraw.executionFee, executionFee);

        vm.stopPrank();
    }

    function testCancelWithdraw() public {
        // First create a withdraw
        testCreateWithdraw();
        uint256 withdrawKey = 0; // First withdraw nonce

        uint256 userMarketTokensBefore = marketToken.balanceOf(user);
        uint256 userWntBefore = wnt.balanceOf(user);

        vm.prank(user);
        router.cancelWithdraw(withdrawKey);

        WithdrawHandler.Withdraw memory withdraw = dataStore.getWithdraw(withdrawKey);
        assertEq(withdraw.account, address(0)); // Withdraw should be cleared
        assertEq(marketToken.balanceOf(user), userMarketTokensBefore + 10 * 10**18); // Market tokens returned
        assertEq(wnt.balanceOf(user), userWntBefore + 0.1 ether); // Execution fee returned
    }

    function testExecuteWithdraw() public {
        testCreateWithdraw();

        // Execute withdraw as keeper
        vm.prank(keeper);

        // Verify user received back long and short tokens
        uint256 longTokenBalanceBefore = IERC20(address(wnt)).balanceOf(user);
        uint256 shortTokenBalanceBefore = IERC20(address(usdc)).balanceOf(user);
        
        // Execute withdraw
        withdrawHandler.executeWithdraw(0);

        // Verify withdraw was executed
        WithdrawHandler.Withdraw memory withdraw = dataStore.getWithdraw(0);
        assertEq(withdraw.account, address(0), "Withdraw should be cleared");

        uint256 longTokenBalanceAfter = IERC20(address(wnt)).balanceOf(user);
        uint256 shortTokenBalanceAfter = IERC20(address(usdc)).balanceOf(user);
        
        assertGt(longTokenBalanceAfter, longTokenBalanceBefore, "Long token balance should have increased after withdraw");
        assertGt(shortTokenBalanceAfter, shortTokenBalanceBefore, "Short token balance should have increased after withdraw");
    }
} 