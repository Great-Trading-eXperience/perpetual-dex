// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/OrderHandler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address market = vm.envAddress("MARKET_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // Approve WETH spending
        IERC20(weth).approve(router, type(uint256).max);

        // Create order parameters
        OrderHandler.CreateOrderParams memory params = OrderHandler.CreateOrderParams({
            receiver: msg.sender,
            cancellationReceiver: msg.sender,
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: market,
            initialCollateralToken: weth,
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

        // Prepare multicall data
        bytes[] memory multicallData = new bytes[](3);

        // Send WETH for execution fee
        multicallData[0] = abi.encodeWithSelector(
            Router.sendWnt.selector,
            vm.envAddress("ORDER_VAULT_ADDRESS"),
            1 * 10**18
        );

        // Send collateral token
        multicallData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            weth,
            vm.envAddress("ORDER_VAULT_ADDRESS"),
            1 * 10**18
        );

        // Create order
        multicallData[2] = abi.encodeWithSelector(
            Router.createOrder.selector,
            params
        );

        Router(router).multicall(multicallData);

        console.log("Order created successfully");

        vm.stopBroadcast();
    }
} 