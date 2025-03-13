// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MarketFactory.sol";
import "../interfaces/IGTXOracleServiceManager.sol";
import "../src/Router.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CreateMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
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

        // 1. Used for internal oracle
        // // Create markets for each token pair
        // address wethMarket = MarketFactory(marketFactory).createMarket(
        //     wethAddress,
        //     shortToken
        // );
        // console.log("WETH_USDC_MARKET_ADDRESS=%s", address(wethMarket));

        // address wbtcMarket = MarketFactory(marketFactory).createMarket(
        //     wbtcAddress, 
        //     shortToken
        // );
        // console.log("WBTC_USDC_MARKET_ADDRESS=%s", address(wbtcMarket));

        // address pepeMarket = MarketFactory(marketFactory).createMarket(
        //     pepeAddress,
        //     shortToken
        // );
        // console.log("PEPE_USDC_MARKET_ADDRESS=%s", address(pepeMarket));

        // address trumpMarket = MarketFactory(marketFactory).createMarket(
        //     trumpAddress,
        //     shortToken
        // );
        // console.log("TRUMP_USDC_MARKET_ADDRESS=%s", address(trumpMarket));

        // address dogeMarket = MarketFactory(marketFactory).createMarket(
        //     dogeAddress,
        //     shortToken
        // );
        // console.log("DOGE_USDC_MARKET_ADDRESS=%s", address(dogeMarket));

        // address linkMarket = MarketFactory(marketFactory).createMarket(
        //     linkAddress,
        //     shortToken
        // );
        // console.log("LINK_USDC_MARKET_ADDRESS=%s", address(linkMarket));

        // 2. Used for external oracle
        // Create WETH/USDC market
        IGTXOracleServiceManager.Source[] memory wethSources = new IGTXOracleServiceManager.Source[](2);
        wethSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "WETHUSDT", network: ""});
        wethSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "WETH-USDT", network: ""});
        address wethMarket = Router(router).createMarket(wethAddress, shortToken, "WETH/USDT", wethSources);
        console.log("WETH_USDC_MARKET_ADDRESS=%s", address(wethMarket));

        // Create WBTC/USDC market
        IGTXOracleServiceManager.Source[] memory wbtcSources = new IGTXOracleServiceManager.Source[](2);
        wbtcSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "WBTCUSDT", network: ""});
        wbtcSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "BTC-USDT", network: ""});
        address wbtcMarket = Router(router).createMarket(wbtcAddress, shortToken, "WBTC/USDT", wbtcSources);
        console.log("WBTC_USDC_MARKET_ADDRESS=%s", address(wbtcMarket));

        // Create PEPE/USDC market
        IGTXOracleServiceManager.Source[] memory pepeSources = new IGTXOracleServiceManager.Source[](2);
        pepeSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "PEPEUSDT", network: ""});
        pepeSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "PEPE-USDT", network: ""});
        address pepeMarket = Router(router).createMarket(pepeAddress, shortToken, "PEPE/USDT", pepeSources);
        console.log("PEPE_USDC_MARKET_ADDRESS=%s", address(pepeMarket));

        // Create TRUMP/USDC market
        IGTXOracleServiceManager.Source[] memory trumpSources = new IGTXOracleServiceManager.Source[](2);
        trumpSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "TRUMPUSDT", network: ""});
        trumpSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "TRUMP-USDT", network: ""});
        address trumpMarket = Router(router).createMarket(trumpAddress, shortToken, "TRUMP/USDT", trumpSources);
        console.log("TRUMP_USDC_MARKET_ADDRESS=%s", address(trumpMarket));

        // Create DOGE/USDC market
        IGTXOracleServiceManager.Source[] memory dogeSources = new IGTXOracleServiceManager.Source[](2);
        dogeSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "DOGEUSDT", network: ""});
        dogeSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "DOGE-USDT", network: ""});
        address dogeMarket = Router(router).createMarket(dogeAddress, shortToken, "DOGE/USDT", dogeSources);
        console.log("DOGE_USDC_MARKET_ADDRESS=%s", address(dogeMarket));

        // Create LINK/USDC market
        IGTXOracleServiceManager.Source[] memory linkSources = new IGTXOracleServiceManager.Source[](2);
        linkSources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "LINKUSDT", network: ""});
        linkSources[1] = IGTXOracleServiceManager.Source({name: "okx", identifier: "LINK-USDT", network: ""});
        address linkMarket = Router(router).createMarket(linkAddress, shortToken, "LINK/USDT", linkSources);
        console.log("LINK_USDC_MARKET_ADDRESS=%s", address(linkMarket));

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
        //     IGTXOracleServiceManager.Source({name: "binance", identifier: "WETHUSDT", network: ""});
        // sources[3] =
        //     IGTXOracleServiceManager.Source({name: "okx", identifier: "WETH-USDT", network: ""});
        // address marketToken =
        //     Router(router).createMarket(longToken, shortToken, "WETH/USDT", sources);
        // console.log("MARKET_ADDRESS=%s", address(marketToken));

        vm.stopBroadcast();
    }
}
