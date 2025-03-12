// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MarketFactory.sol";
import "../interfaces/IGTXOracleServiceManager.sol";
import "../src/Router.sol";

contract CreateMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketFactory = vm.envAddress("MARKET_FACTORY_ADDRESS");
        address shortToken = vm.envAddress("USDC_ADDRESS");

        // Get token addresses from environment variables
        address wethAddress = vm.envAddress("WETH_ADDRESS"); 
        address wbtcAddress = vm.envAddress("WBTC_ADDRESS");
        address pepeAddress = vm.envAddress("PEPE_ADDRESS");
        address trumpAddress = vm.envAddress("TRUMP_ADDRESS");
        address dogeAddress = vm.envAddress("DOGE_ADDRESS");
        address linkAddress = vm.envAddress("LINK_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Create markets for each token pair
        address wethMarket = MarketFactory(marketFactory).createMarket(
            wethAddress,
            shortToken
        );
        console.log("WETH_USDC_MARKET_ADDRESS=%s", address(wethMarket));

        address wbtcMarket = MarketFactory(marketFactory).createMarket(
            wbtcAddress, 
            shortToken
        );
        console.log("WBTC_USDC_MARKET_ADDRESS=%s", address(wbtcMarket));

        address pepeMarket = MarketFactory(marketFactory).createMarket(
            pepeAddress,
            shortToken
        );
        console.log("PEPE_USDC_MARKET_ADDRESS=%s", address(pepeMarket));

        address trumpMarket = MarketFactory(marketFactory).createMarket(
            trumpAddress,
            shortToken
        );
        console.log("TRUMP_USDC_MARKET_ADDRESS=%s", address(trumpMarket));

        address dogeMarket = MarketFactory(marketFactory).createMarket(
            dogeAddress,
            shortToken
        );
        console.log("DOGE_USDC_MARKET_ADDRESS=%s", address(dogeMarket));

        address linkMarket = MarketFactory(marketFactory).createMarket(
            linkAddress,
            shortToken
        );
        console.log("LINK_USDC_MARKET_ADDRESS=%s", address(linkMarket));

        vm.stopBroadcast();
    }
}
