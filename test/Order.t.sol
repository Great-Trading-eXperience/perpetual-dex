// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/Router.sol";
import "../src/OrderHandler.sol";
import "../src/OrderVault.sol";
import "../src/DataStore.sol";
import "../src/MarketFactory.sol";
import "../src/MarketToken.sol";
import "../src/MarketHandler.sol";
import "../src/Oracle.sol";
import "../src/PositionHandler.sol";
import "../src/DepositHandler.sol";
import "../src/DepositVault.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1_000_000 * 1e18);
    }
}

contract OrderTest is Test {
    Router public router;
    OrderHandler public orderHandler;
    OrderVault public orderVault;
    DataStore public dataStore;
    MarketFactory public marketFactory;
    MarketHandler public marketHandler;
    MarketToken public marketToken;
    PositionHandler public positionHandler;
    Oracle public oracle;
    MockToken public wnt;
    MockToken public usdc;
    DepositHandler public depositHandler;
    DepositVault public depositVault;

    address depositor = address(1);
    address trader = address(2);
    address keeper = address(3);

    uint256 constant SIGNER_PK = 0x12345;
    uint256 executionFee = 1 * 10e6;

    function setUp() public {
        // Deploy mock tokens first
        wnt = new MockToken();
        usdc = new MockToken();

        // Deploy core contracts
        dataStore = new DataStore();
        orderVault = new OrderVault();

        // Deploy Oracle
        oracle = new Oracle(1, 100); // min/max block interval
        oracle.setSigner(address(wnt), vm.addr(SIGNER_PK), true);
        oracle.setSigner(address(usdc), vm.addr(SIGNER_PK), true);
        oracle.setMinSigners(address(wnt), 1);
        oracle.setMinSigners(address(usdc), 1);
        oracle.setMaxPriceAge(address(wnt), 3600);
        oracle.setMaxPriceAge(address(usdc), 3600);

        // Deploy handlers in correct order
        marketHandler = new MarketHandler(address(dataStore), address(oracle));
        positionHandler =
            new PositionHandler(address(dataStore), address(oracle), address(marketHandler));
        orderHandler = new OrderHandler(
            address(dataStore),
            address(orderVault),
            address(wnt),
            address(oracle),
            address(positionHandler),
            address(marketHandler)
        );

        // Deploy MarketFactory
        marketFactory = new MarketFactory(address(dataStore));

        // Set up contract relationships
        positionHandler.setOrderHandler(address(orderHandler));
        marketHandler.setPositionHandler(address(positionHandler));

        // Create market and get market token
        address marketTokenAddress = marketFactory.createMarket(address(wnt), address(usdc));
        marketToken = MarketToken(marketTokenAddress);

        // Deploy deposit related contracts
        depositVault = new DepositVault();
        depositHandler = new DepositHandler(
            address(dataStore), address(depositVault), address(marketHandler), address(wnt)
        );

        // Deploy Router last since it needs other contracts
        router = new Router(
            address(dataStore),
            address(depositHandler),
            address(0),
            address(orderHandler),
            address(wnt),
            address(positionHandler),
            address(marketFactory),
            address(oracle)
        );

        // Fund deppsitor
        wnt.transfer(depositor, 10_000 * 1e18);
        usdc.transfer(depositor, 10_000 * 1e18);
        vm.deal(depositor, 100 ether);

        // Approve tokens
        vm.startPrank(depositor);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Fund keeper
        wnt.transfer(keeper, 10_000 * 1e18);
        usdc.transfer(keeper, 10_000 * 1e18);
        vm.deal(keeper, 100 ether);

        // Approve tokens
        vm.startPrank(keeper);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Fund trader
        wnt.transfer(trader, 20 * 1e18);
        usdc.transfer(trader, 20 * 1e18);
        vm.deal(trader, 100 ether);

        // Approve tokens
        vm.startPrank(trader);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testCreateOrderUsingWnt() public {
        vm.startPrank(trader);

        uint256 initialCollateralDeltaAmount = 1 * 1e18;
        uint256 sizeDeltaUsd = initialCollateralDeltaAmount * 3000 * 10;
        uint256 triggerPrice = 3000 * 1e18;
        uint256 acceptablePrice = (triggerPrice * 110) / 100;

        OrderHandler.CreateOrderParams memory params = OrderHandler.CreateOrderParams({
            receiver: trader,
            cancellationReceiver: trader,
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: address(marketToken),
            initialCollateralToken: address(wnt),
            orderType: OrderHandler.OrderType.MarketIncrease,
            sizeDeltaUsd: sizeDeltaUsd,
            initialCollateralDeltaAmount: initialCollateralDeltaAmount,
            triggerPrice: triggerPrice,
            acceptablePrice: acceptablePrice,
            executionFee: executionFee,
            validFromTime: 0,
            isLong: true,
            autoCancel: false
        });

        bytes[] memory multicallData = new bytes[](3);

        // Send WNT for execution fee
        multicallData[0] =
            abi.encodeWithSelector(Router.sendWnt.selector, address(orderVault), executionFee);

        // Send collateral token
        multicallData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(wnt),
            address(orderVault),
            initialCollateralDeltaAmount
        );

        // Create order
        multicallData[2] = abi.encodeWithSelector(Router.createOrder.selector, params);

        router.multicall(multicallData);

        OrderHandler.Order memory order = dataStore.getOrder(0);
        assertEq(order.account, trader);
        assertEq(order.sizeDeltaUsd, initialCollateralDeltaAmount * 3000 * 10);
        assertEq(order.initialCollateralDeltaAmount, initialCollateralDeltaAmount);

        vm.stopPrank();
    }

    function testCancelOrder() public {
        testCreateOrderUsingWnt();

        vm.startPrank(trader);

        router.cancelOrder(0);

        OrderHandler.Order memory order = dataStore.getOrder(0);
        assertEq(order.account, address(0)); // Order should be cleared
        assertEq(order.sizeDeltaUsd, 0);

        vm.stopPrank();
    }

    function createInitialDeposit() internal {
        vm.startPrank(depositor);

        // Create deposit params
        DepositHandler.CreateDepositParams memory params = DepositHandler.CreateDepositParams({
            receiver: depositor,
            uiFeeReceiver: address(0),
            market: address(marketToken),
            initialLongToken: address(wnt),
            initialShortToken: address(usdc),
            minMarketTokens: 0,
            executionFee: 1 * 10e6
        });

        // Prepare multicall data for deposit
        bytes[] memory depositData = new bytes[](4);

        // 1. Transfer WNT for execution fee
        depositData[0] = abi.encodeCall(Router.sendWnt, (address(depositVault), 1 * 10e6));

        // 2. Transfer WNT as long token (10 WNT)
        depositData[1] =
            abi.encodeCall(Router.sendTokens, (address(wnt), address(depositVault), 100 * 1e18));

        // 3. Transfer USDC as short token (3,000 USDC)
        depositData[2] =
            abi.encodeCall(Router.sendTokens, (address(usdc), address(depositVault), 3000 * 1e18));

        // 4. Create deposit
        depositData[3] = abi.encodeCall(Router.createDeposit, (params));

        router.multicall(depositData);

        vm.stopPrank();
    }

    function testExecuteOrder() public {
        uint256 wntPrice = 3000 * 1e18; // $3000 per WNT
        uint256 usdcPrice = 1 * 1e18; // $1 per USDC

        // Set oracle prices first
        setOraclePrices(wntPrice, usdcPrice);

        // First create deposit to provide liquidity
        createInitialDeposit();

        // Execute deposit as keeper to provide liquidity
        vm.startPrank(keeper);
        depositHandler.executeDeposit(0); // First deposit has key 0
        vm.stopPrank();

        // Create order
        testCreateOrderUsingWnt();

        // Record balances before execution
        uint256 keeperBalanceBefore = IERC20(wnt).balanceOf(keeper);
        uint256 marketTokenLongBefore = IERC20(wnt).balanceOf(address(marketToken));
        uint256 traderLongBefore = IERC20(wnt).balanceOf(trader);

        // Execute order as keeper
        vm.startPrank(keeper);
        orderHandler.executeOrder(0); // First order has key 0
        vm.stopPrank();

        // Verify order was executed
        OrderHandler.Order memory order = dataStore.getOrder(0);
        assertEq(order.account, address(0), "Order should be cleared after execution");

        // Verify keeper received execution fee
        assertEq(
            IERC20(wnt).balanceOf(keeper),
            keeperBalanceBefore + executionFee,
            "Keeper should receive execution fee"
        );

        // Verify position was created
        bytes32 positionKey =
            keccak256(abi.encodePacked(trader, address(marketToken), address(wnt)));
        PositionHandler.Position memory position = dataStore.getPosition(positionKey);

        uint256 positionFee = (position.sizeInTokens * positionHandler.POSITION_FEE()) / 10_000;

        // Verify position details
        assertEq(position.account, trader, "Position account should be trader");
        assertEq(position.market, address(marketToken), "Position market should be correct");
        assertEq(position.collateralToken, address(wnt), "Position collateral token should be WNT");
        assertEq(position.sizeInUsd, 30_000 * 1e18, "Position size should be correct"); // 1 WNT * $3000 * 10x
        assertEq(
            position.collateralAmount,
            1 * 1e18 - positionFee,
            "Position collateral should be correct"
        );
        assertEq(position.isLong, true, "Position should be long");

        // Verify token transfers
        assertEq(
            IERC20(wnt).balanceOf(address(marketToken)),
            marketTokenLongBefore + 1 * 1e18,
            "Market should receive collateral"
        );
        assertEq(
            IERC20(wnt).balanceOf(trader),
            traderLongBefore,
            "Trader balance should not change after execution"
        );

        // Verify open interest was updated
        uint256 openInterest = marketHandler.getOpenInterest(address(marketToken), address(wnt));
        assertEq(openInterest, position.sizeInTokens, "Open interest should be updated");

        // Log position details for debugging
        console.log("Position size in USD:", position.sizeInUsd);
        console.log("Position collateral:", position.collateralAmount);
        console.log("Position open interest:", openInterest);
    }

    function testLiquidation() public {
        testExecuteOrder();

        vm.startPrank(keeper);

        vm.warp(block.timestamp + 3600);

        setOraclePrices(2700 * 1e18, 1 * 1e18);

        router.liquidatePosition(
            PositionHandler.LiquidatePositionParams({
                account: trader,
                market: address(marketToken),
                collateralToken: address(wnt)
            })
        );

        bytes32 positionKey =
            keccak256(abi.encodePacked(trader, address(marketToken), address(wnt)));

        PositionHandler.Position memory position = dataStore.getPosition(positionKey);
        assertEq(position.sizeInTokens, 0, "Position size should be 0");
        assertEq(position.sizeInUsd, 0, "Position size in USD should be 0");
        assertEq(position.collateralAmount, 0, "Position collateral should be 0");

        vm.stopPrank();
    }

    function setOraclePrices(uint256 wntPrice, uint256 usdcPrice) internal {
        address[] memory tokens = new address[](2);
        tokens[0] = address(wnt);
        tokens[1] = address(usdc);

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](2);

        // Sign WNT price
        bytes32 wntMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(address(wnt), wntPrice, block.timestamp, block.number))
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(SIGNER_PK, wntMessageHash);
        signedPrices[0] = Oracle.SignedPrice({
            price: wntPrice,
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r1, s1, v1)
        });

        // Sign USDC price
        bytes32 usdcMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(address(usdc), usdcPrice, block.timestamp, block.number))
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(SIGNER_PK, usdcMessageHash);
        signedPrices[1] = Oracle.SignedPrice({
            price: usdcPrice,
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r2, s2, v2)
        });

        vm.roll(block.number + 2);
        oracle.setPrices(tokens, signedPrices);
    }
}
