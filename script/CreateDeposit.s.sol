// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/DepositHandler.sol";
import "../src/MarketFactory.sol";
import "../src/mocks/MockToken.sol";

contract CreateDepositScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address depositVault = vm.envAddress("DEPOSIT_VAULT_ADDRESS");

        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");
        address pepe = vm.envAddress("PEPE_ADDRESS");
        address doge = vm.envAddress("DOGE_ADDRESS");
        address trump = vm.envAddress("TRUMP_ADDRESS");
        address link = vm.envAddress("LINK_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Get market addresses
        address wethUsdcMarket = vm.envAddress("WETH_USDC_MARKET_ADDRESS");
        address wbtcUsdcMarket = vm.envAddress("WBTC_USDC_MARKET_ADDRESS");
        address pepeUsdcMarket = vm.envAddress("PEPE_USDC_MARKET_ADDRESS");
        address dogeUsdcMarket = vm.envAddress("DOGE_USDC_MARKET_ADDRESS");
        address trumpUsdcMarket = vm.envAddress("TRUMP_USDC_MARKET_ADDRESS");
        address linkUsdcMarket = vm.envAddress("LINK_USDC_MARKET_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Mint tokens with large amounts
        MockToken(weth).mint(vm.addr(deployerPrivateKey), 10000 * 1e18);    // 1000 WETH
        MockToken(wbtc).mint(vm.addr(deployerPrivateKey), 10000 * 1e18);     // 100 WBTC
        MockToken(pepe).mint(vm.addr(deployerPrivateKey), 10000000 * 1e18); // 100M PEPE
        MockToken(doge).mint(vm.addr(deployerPrivateKey), 1000000 * 1e8); // 10M DOGE
        MockToken(trump).mint(vm.addr(deployerPrivateKey), 100000 * 1e18); // 1M TRUMP
        MockToken(link).mint(vm.addr(deployerPrivateKey), 10000 * 1e18);  // 100K LINK
        MockToken(usdc).mint(vm.addr(deployerPrivateKey), 1000000 * 1e6); // 10M USDC

        // Approve all tokens
        IERC20(weth).approve(router, type(uint256).max);
        IERC20(wbtc).approve(router, type(uint256).max);
        IERC20(pepe).approve(router, type(uint256).max);
        IERC20(doge).approve(router, type(uint256).max);
        IERC20(trump).approve(router, type(uint256).max);
        IERC20(link).approve(router, type(uint256).max);
        IERC20(usdc).approve(router, type(uint256).max);

        // Base parameters
        uint256 executionFee = 1 * 1e9;

        // Add large liquidity to WETH-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            wethUsdcMarket,
            weth,           // Long token (WETH)
            usdc,           // Short token (USDC)
            100 * 1e18,    // 100 WETH ($200,000)
            600000 * 1e6,  // 600,000 USDC
            0,             // Min market tokens
            executionFee
        );

        // Add large liquidity to WBTC-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            wbtcUsdcMarket,
            wbtc,           // Long token (WBTC)
            usdc,           // Short token (USDC)
            50 * 1e18,     // 50 WBTC ($2.1M)
            6300000 * 1e6, // 6.3M USDC
            0,             // Min market tokens
            executionFee
        );

        // Add large liquidity to PEPE-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            pepeUsdcMarket,
            pepe,            // Long token (PEPE)
            usdc,           // Short token (USDC)
            50000000 * 1e18, // 50M PEPE ($5,000)
            15000 * 1e6,    // 15,000 USDC
            0,             // Min market tokens
            executionFee
        );

        // Add large liquidity to DOGE-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            dogeUsdcMarket,
            doge,           // Long token (DOGE)
            usdc,           // Short token (USDC)
            1000000 * 1e8, // 1M DOGE ($100,000)
            300000 * 1e6,  // 300,000 USDC
            0,             // Min market tokens
            executionFee
        );

        // Add large liquidity to TRUMP-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            trumpUsdcMarket,
            trump,          // Long token (TRUMP)
            usdc,          // Short token (USDC)
            500000 * 1e18, // 500K TRUMP ($25,000)
            75000 * 1e6,   // 75,000 USDC
            0,             // Min market tokens
            executionFee
        );

        // Add large liquidity to LINK-USDC market (1:3 ratio)
        createMarketDeposit(
            router,
            depositVault,
            linkUsdcMarket,
            link,           // Long token (LINK)
            usdc,           // Short token (USDC)
            10000 * 1e18,  // 10K LINK ($150,000)
            450000 * 1e6,  // 450,000 USDC
            0,             // Min market tokens
            executionFee
        );

        console.log("Large liquidity deposits created successfully for all markets");

        vm.stopBroadcast();
    }

    function createMarketDeposit(
        address router,
        address depositVault,
        address market,
        address longToken,
        address shortToken,
        uint256 longTokenAmount,
        uint256 shortTokenAmount,
        uint256 minMarketTokens,
        uint256 executionFee
    ) internal {
        DepositHandler.CreateDepositParams memory params = DepositHandler
            .CreateDepositParams({
                receiver: msg.sender,
                uiFeeReceiver: address(0),
                market: market,
                initialLongToken: longToken,
                initialShortToken: shortToken,
                minMarketTokens: minMarketTokens,
                executionFee: executionFee
            });

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (depositVault, executionFee)
        );

        data[1] = abi.encodeCall(
            Router.sendTokens,
            (longToken, depositVault, longTokenAmount)
        );

        data[2] = abi.encodeCall(
            Router.sendTokens,
            (shortToken, depositVault, shortTokenAmount)
        );

        data[3] = abi.encodeCall(Router.createDeposit, (params));

        Router(router).multicall(data);

        uint256 balanceOfMarketToken = IERC20(market).balanceOf(msg.sender);
        console.log("Balance of market token for %s: %s", market, balanceOfMarketToken);
    }
}