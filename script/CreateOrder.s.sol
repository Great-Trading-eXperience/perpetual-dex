// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/OrderHandler.sol";
import "../src/MarketFactory.sol";
import "../src/mocks/MockToken.sol";

contract CreateOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address orderVault = vm.envAddress("ORDER_VAULT_ADDRESS");
        
        // Get token addresses
        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");
        address pepe = vm.envAddress("PEPE_ADDRESS");
        address doge = vm.envAddress("DOGE_ADDRESS");
        address trump = vm.envAddress("TRUMP_ADDRESS");
        address link = vm.envAddress("LINK_ADDRESS");

        // Get market addresses
        address wethUsdcMarket = vm.envAddress("WETH_USDC_MARKET_ADDRESS");
        address wbtcUsdcMarket = vm.envAddress("WBTC_USDC_MARKET_ADDRESS");
        address pepeUsdcMarket = vm.envAddress("PEPE_USDC_MARKET_ADDRESS");
        address dogeUsdcMarket = vm.envAddress("DOGE_USDC_MARKET_ADDRESS");
        address trumpUsdcMarket = vm.envAddress("TRUMP_USDC_MARKET_ADDRESS");
        address linkUsdcMarket = vm.envAddress("LINK_USDC_MARKET_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Mint tokens first
        MockToken(weth).mint(vm.addr(deployerPrivateKey), 10 * 1e18);    // 10 WETH
        MockToken(wbtc).mint(vm.addr(deployerPrivateKey), 1 * 1e18);     // 1 WBTC
        MockToken(pepe).mint(vm.addr(deployerPrivateKey), 1000000 * 1e18); // 1M PEPE
        MockToken(doge).mint(vm.addr(deployerPrivateKey), 10000 * 1e18);  // 10K DOGE
        MockToken(trump).mint(vm.addr(deployerPrivateKey), 10000 * 1e18); // 10K TRUMP
        MockToken(link).mint(vm.addr(deployerPrivateKey), 1000 * 1e18);   // 1K LINK

        // Approve all tokens
        IERC20(weth).approve(router, type(uint256).max);
        IERC20(wbtc).approve(router, type(uint256).max);
        IERC20(pepe).approve(router, type(uint256).max);
        IERC20(doge).approve(router, type(uint256).max);
        IERC20(trump).approve(router, type(uint256).max);
        IERC20(link).approve(router, type(uint256).max);

        // Base parameters
        uint256 executionFee = 1 * 1e9;

        // Create orders with smaller amounts
        createMarketOrder(
            router,
            orderVault,
            wethUsdcMarket,
            weth,           // Using WETH as collateral
            0.1 * 1e18,    // 0.1 WETH as collateral ($200)
            2000 * 1e18,   // $2,000 size (10x)
            0,             // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true           // Long position
        );

        // Create long WBTC order (10x leverage)
        createMarketOrder(
            router,
            orderVault,
            wbtcUsdcMarket,
            wbtc,           // Using WBTC as collateral
            0.01 * 1e18,   // 0.01 WBTC as collateral ($420)
            4200 * 1e18,   // $4,200 size (10x)
            0,             // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true           // Long position
        );

        // Create long PEPE order (10x leverage)
        createMarketOrder(
            router,
            orderVault,
            pepeUsdcMarket,
            pepe,            // Using PEPE as collateral
            100000 * 1e18,  // 100K PEPE as collateral ($10)
            100 * 1e18,     // $100 size (10x)
            0,              // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true            // Long position
        );

        // Create long DOGE order (10x leverage)
        createMarketOrder(
            router,
            orderVault,
            dogeUsdcMarket,
            doge,           // Using DOGE as collateral
            1000 * 1e18,   // 1,000 DOGE as collateral ($100)
            1000 * 1e18,   // $1,000 size (10x)
            0,             // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true           // Long position
        );

        // Create long TRUMP order (10x leverage)
        createMarketOrder(
            router,
            orderVault,
            trumpUsdcMarket,
            trump,          // Using TRUMP as collateral
            1000 * 1e18,   // 1,000 TRUMP as collateral ($50)
            500 * 1e18,    // $500 size (10x)
            0,             // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true           // Long position
        );

        // Create long LINK order (10x leverage)
        createMarketOrder(
            router,
            orderVault,
            linkUsdcMarket,
            link,           // Using LINK as collateral
            10 * 1e18,     // 10 LINK as collateral ($150)
            1500 * 1e18,   // $1,500 size (10x)
            0,             // Trigger price 0 for immediate execution
            type(uint256).max, // Accept any price
            executionFee,
            true           // Long position
        );

        console.log("Orders created successfully for all markets");

        vm.stopBroadcast();
    }

    function createMarketOrder(
        address router,
        address orderVault,
        address market,
        address collateralToken,
        uint256 collateralAmount,
        uint256 sizeDeltaUsd,
        uint256 triggerPrice,
        uint256 acceptablePrice,
        uint256 executionFee,
        bool isLong
    ) internal {
        OrderHandler.CreateOrderParams memory params = OrderHandler
            .CreateOrderParams({
                receiver: msg.sender,
                cancellationReceiver: msg.sender,
                callbackContract: address(0),
                uiFeeReceiver: address(0),
                market: market,
                initialCollateralToken: collateralToken,
                orderType: OrderHandler.OrderType.MarketIncrease,
                sizeDeltaUsd: sizeDeltaUsd,
                initialCollateralDeltaAmount: collateralAmount,
                triggerPrice: triggerPrice,
                acceptablePrice: acceptablePrice,
                executionFee: executionFee,
                validFromTime: 0,
                isLong: isLong,
                autoCancel: false
            });

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (orderVault, executionFee)
        );

        data[1] = abi.encodeCall(
            Router.sendTokens,
            (collateralToken, orderVault, collateralAmount)
        );

        data[2] = abi.encodeCall(Router.createOrder, (params));

        Router(router).multicall(data);
    }
} 