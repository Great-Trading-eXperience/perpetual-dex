// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/Router.sol";
import "../src/OrderHandler.sol";
import "../src/OrderVault.sol";
import "../src/DataStore.sol";
import "../src/MarketFactory.sol";
import "../src/MarketToken.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract OrderTest is Test {
    Router public router;
    OrderHandler public orderHandler;
    OrderVault public orderVault;
    DataStore public dataStore;
    MarketFactory public marketFactory;
    MarketToken public marketToken;
    MockToken public wnt;
    MockToken public usdc;
    
    address user = address(1);

    function setUp() public {
        // Deploy contracts
        wnt = new MockToken();
        usdc = new MockToken();
        dataStore = new DataStore();
        orderVault = new OrderVault();
        orderHandler = new OrderHandler(address(orderVault), address(wnt));
        marketFactory = new MarketFactory(address(dataStore));
        
        router = new Router(
            address(dataStore),
            address(0), // depositHandler not needed for this test
            address(0), // withdrawHandler not needed for this test
            address(orderHandler),
            address(wnt)
        );

        // Setup market
        address marketTokenAddress = marketFactory.createMarket(
            address(wnt),
            address(usdc)
        );

        marketToken = MarketToken(marketTokenAddress);

        // Fund user
        wnt.transfer(user, 100 * 10**18);
        usdc.transfer(user, 100 * 10**18);
        vm.deal(user, 100 ether);

        // Approve tokens
        vm.startPrank(user);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testCreateOrderUsingWnt() public {
        vm.startPrank(user);
        
        OrderHandler.CreateOrderParams memory params = OrderHandler.CreateOrderParams({
            receiver: user,
            cancellationReceiver: user,
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: address(marketToken),
            initialCollateralToken: address(wnt),
            orderType: OrderHandler.OrderType.MarketIncrease,
            sizeDeltaUsd: 1000 * 10**18,
            initialCollateralDeltaAmount: 1 * 10**18,
            triggerPrice: 0,
            acceptablePrice: 1000 * 10**18,
            executionFee: 1 * 10**6,
            validFromTime: 0,
            isLong: true,
            autoCancel: false
        });

        bytes[] memory multicallData = new bytes[](3);

        // Send WNT for execution fee
        multicallData[0] = abi.encodeWithSelector(
            Router.sendWnt.selector,
            address(orderVault),
            1 * 10**18
        );

        // Send collateral token
        multicallData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(wnt),
            address(orderVault),
            1 * 10**18
        );

        // Create order
        multicallData[2] = abi.encodeWithSelector(
            Router.createOrder.selector,
            params
        );

        router.multicall(multicallData);

        OrderHandler.Order memory order = dataStore.getOrder(0);
        assertEq(order.account, user);
        assertEq(order.sizeDeltaUsd, 1000 * 10**18 - 1 * 10**6);
        assertEq(order.initialCollateralDeltaAmount, 1 * 10**18);

        vm.stopPrank();
    }

    function testCancelOrder() public {
        testCreateOrderUsingWnt();

        vm.startPrank(user);
        
        router.cancelOrder(0);

        OrderHandler.Order memory order = dataStore.getOrder(0);
        assertEq(order.account, address(0)); // Order should be cleared
        assertEq(order.sizeDeltaUsd, 0);
        
        vm.stopPrank();
    }
} 