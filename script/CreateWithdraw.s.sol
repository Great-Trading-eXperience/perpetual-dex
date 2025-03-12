// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/WithdrawHandler.sol";
import "../src/MarketFactory.sol";
import "../src/mocks/MockToken.sol";

contract CreateWithdrawScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address withdrawVault = vm.envAddress("WITHDRAW_VAULT_ADDRESS");

        // Get market addresses
        address wethUsdcMarket = vm.envAddress("WETH_USDC_MARKET_ADDRESS");
        address wbtcUsdcMarket = vm.envAddress("WBTC_USDC_MARKET_ADDRESS");
        address pepeUsdcMarket = vm.envAddress("PEPE_USDC_MARKET_ADDRESS");
        address dogeUsdcMarket = vm.envAddress("DOGE_USDC_MARKET_ADDRESS");
        address trumpUsdcMarket = vm.envAddress("TRUMP_USDC_MARKET_ADDRESS");
        address linkUsdcMarket = vm.envAddress("LINK_USDC_MARKET_ADDRESS");

        // Get token addresses
        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");
        address pepe = vm.envAddress("PEPE_ADDRESS");
        address doge = vm.envAddress("DOGE_ADDRESS");
        address trump = vm.envAddress("TRUMP_ADDRESS");
        address link = vm.envAddress("LINK_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Approve market tokens
        IERC20(wethUsdcMarket).approve(router, type(uint256).max);
        IERC20(wbtcUsdcMarket).approve(router, type(uint256).max);
        IERC20(pepeUsdcMarket).approve(router, type(uint256).max);
        IERC20(dogeUsdcMarket).approve(router, type(uint256).max);
        IERC20(trumpUsdcMarket).approve(router, type(uint256).max);
        IERC20(linkUsdcMarket).approve(router, type(uint256).max);

        uint256 executionFee = 1 * 1e9;

        // Create withdrawals with percentage amounts
        createMarketWithdraw(
            router,
            withdrawVault,
            wethUsdcMarket,
            weth,           // Long token (WETH)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (WETH)
            50,            // 50% in short token (USDC)
            executionFee
        );

        createMarketWithdraw(
            router,
            withdrawVault,
            wbtcUsdcMarket,
            wbtc,           // Long token (WBTC)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (WBTC)
            50,            // 50% in short token (USDC)
            executionFee
        );

        createMarketWithdraw(
            router,
            withdrawVault,
            pepeUsdcMarket,
            pepe,           // Long token (PEPE)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (PEPE)
            50,            // 50% in short token (USDC)
            executionFee
        );

        createMarketWithdraw(
            router,
            withdrawVault,
            dogeUsdcMarket,
            doge,           // Long token (DOGE)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (DOGE)
            50,            // 50% in short token (USDC)
            executionFee
        );

        createMarketWithdraw(
            router,
            withdrawVault,
            trumpUsdcMarket,
            trump,          // Long token (TRUMP)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (TRUMP)
            50,            // 50% in short token (USDC)
            executionFee
        );

        createMarketWithdraw(
            router,
            withdrawVault,
            linkUsdcMarket,
            link,           // Long token (LINK)
            usdc,           // Short token (USDC)
            0.01 * 1e18,   // Market token amount
            50,            // 50% in long token (LINK)
            50,            // 50% in short token (USDC)
            executionFee
        );

        console.log("Withdrawals created successfully for all markets");

        vm.stopBroadcast();
    }

    function createMarketWithdraw(
        address router,
        address withdrawVault,
        address marketToken,
        address longToken,
        address shortToken,
        uint256 marketTokenAmount,
        uint256 longTokenPercent,  // Percentage of withdrawal in long token
        uint256 shortTokenPercent, // Percentage of withdrawal in short token
        uint256 executionFee
    ) internal {
        uint256 balanceBefore = IERC20(marketToken).balanceOf(msg.sender);
        console.log("Market Token Balance Before Withdrawal:", balanceBefore);

        WithdrawHandler.CreateWithdrawParams memory params = WithdrawHandler
            .CreateWithdrawParams({
                receiver: msg.sender,
                uiFeeReceiver: address(0),
                marketToken: marketToken,
                longToken: longToken,
                shortToken: shortToken,
                marketTokenAmount: marketTokenAmount,
                longTokenAmount: longTokenPercent,    // Percentage amount
                shortTokenAmount: shortTokenPercent,  // Percentage amount
                executionFee: executionFee
            });

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (withdrawVault, executionFee)
        );

        data[1] = abi.encodeCall(
            Router.sendTokens,
            (marketToken, withdrawVault, marketTokenAmount)
        );

        data[2] = abi.encodeCall(Router.createWithdraw, (params));

        Router(router).multicall(data);
    }
} 