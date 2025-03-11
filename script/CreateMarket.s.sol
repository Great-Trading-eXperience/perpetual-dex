// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MarketFactory.sol";
import "../interfaces/IGTXOracleServiceManager.sol";
import "../src/Router.sol";

contract CreateMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // address marketFactory = vm.envAddress("MARKET_FACTORY_ADDRESS");
        address shortToken = vm.envAddress("USDC_ADDRESS");
        address router = vm.envAddress("ROUTER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // address marketToken = MarketFactory(marketFactory).createMarket(
        //     longToken,
        //     shortToken
        // );

        // console.log("MARKET_ADDRESS=%s", address(marketToken));

        // address longToken = vm.envAddress("WETH_ADDRESS");
        // IGTXOracleServiceManager.Source[] memory sources = new IGTXOracleServiceManager.Source[](4);
        // sources[0] = IGTXOracleServiceManager.Source({
        //     name: "geckoterminal",
        //     identifier: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        //     network: "eth"
        // });
        // sources[1] = IGTXOracleServiceManager.Source({
        //     name: "dexscreener",
        //     identifier: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
        //     network: "ethereum"
        // });
        // sources[2] =
        //     IGTXOracleServiceManager.Source({name: "binance", identifier: "ETHUSDT", network: ""});
        // sources[3] =
        //     IGTXOracleServiceManager.Source({name: "okx", identifier: "ETH-USDT", network: ""});

        // address marketToken =
        //     Router(router).createMarket(longToken, shortToken, "ETH/USDT", sources);
        // console.log("MARKET_ADDRESS=%s", address(marketToken));

        address longToken = vm.envAddress("WBTC_ADDRESS");
        IGTXOracleServiceManager.Source[] memory sources = new IGTXOracleServiceManager.Source[](4);
        sources[0] = IGTXOracleServiceManager.Source({
            name: "geckoterminal",
            identifier: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
            network: "eth"
        });
        sources[1] = IGTXOracleServiceManager.Source({
            name: "dexscreener",
            identifier: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
            network: "ethereum"
        });
        sources[2] =
            IGTXOracleServiceManager.Source({name: "binance", identifier: "WBTCUSDT", network: ""});
        sources[3] =
            IGTXOracleServiceManager.Source({name: "okx", identifier: "WBTC-USDT", network: ""});
        address marketToken =
            Router(router).createMarket(longToken, shortToken, "WBTC/USDT", sources);
        console.log("MARKET_ADDRESS=%s", address(marketToken));

        vm.stopBroadcast();
    }
}
