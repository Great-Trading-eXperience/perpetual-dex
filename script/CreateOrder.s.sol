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

        uint256 executionFee = 1 * 10e9;
        uint256 initialCollateralDeltaAmount = 1 * 1e18;
        uint256 sizeDeltaUsd = initialCollateralDeltaAmount * 3000 * 10;
        uint256 triggerPrice = 3000 * 1e18;
        uint256 acceptablePrice = (triggerPrice * 110) / 100;

        // Create order parameters
        OrderHandler.CreateOrderParams memory params = OrderHandler.CreateOrderParams({
            receiver: msg.sender,
            cancellationReceiver: msg.sender,
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            market: market,
            initialCollateralToken: weth,
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

        // Prepare multicall data
        bytes[] memory multicallData = new bytes[](3);

        // Send WETH for execution fee
        multicallData[0] = abi.encodeWithSelector(
            Router.sendWnt.selector,
            vm.envAddress("ORDER_VAULT_ADDRESS"),
            executionFee
        );

        // Send collateral token
        multicallData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            weth,
            vm.envAddress("ORDER_VAULT_ADDRESS"),
            initialCollateralDeltaAmount
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