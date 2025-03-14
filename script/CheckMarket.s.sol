// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Oracle.sol";
import "../src/Router.sol";
import "../src/MarketFactory.sol";
import "../src/DataStore.sol";
import "../src/OrderHandler.sol";
import "../src/OrderVault.sol";
import "../src/DepositHandler.sol";
import "../src/DepositVault.sol";
import "../src/MarketToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address shortToken = vm.envAddress("USDC_ADDRESS");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // address[] memory longTokens = new address[](6);
        // longTokens[0] = vm.envAddress("WBTC_ADDRESS");
        // longTokens[1] = vm.envAddress("WETH_ADDRESS");
        // longTokens[2] = vm.envAddress("PEPE_ADDRESS");
        // longTokens[3] = vm.envAddress("TRUMP_ADDRESS");
        // longTokens[4] = vm.envAddress("DOGE_ADDRESS");
        // longTokens[5] = vm.envAddress("LINK_ADDRESS");

        // for (uint256 i = 0; i < longTokens.length; i++) {
        //     MarketFactory.Market memory market = DataStore(dataStore).getMarket(
        //         keccak256(abi.encodePacked(longTokens[i], shortToken))
        //     );

        //     console.log("MARKET_TOKEN_ADDRESS=%s", market.marketToken);
        //     console.log("LONG_TOKEN_ADDRESS=%s", market.longToken);
        //     console.log("SHORT_TOKEN_ADDRESS=%s", market.shortToken);
        //     console.log("MARKET_STATUS=%s", uint256(market.status));
        // }

        address[] memory marketAddresses = new address[](6);
        marketAddresses[0] = vm.envAddress("WETH_USDC_MARKET_ADDRESS");
        marketAddresses[1] = vm.envAddress("WBTC_USDC_MARKET_ADDRESS");
        marketAddresses[2] = vm.envAddress("PEPE_USDC_MARKET_ADDRESS");
        marketAddresses[3] = vm.envAddress("TRUMP_USDC_MARKET_ADDRESS");
        marketAddresses[4] = vm.envAddress("DOGE_USDC_MARKET_ADDRESS");
        marketAddresses[5] = vm.envAddress("LINK_USDC_MARKET_ADDRESS");

        for (uint256 i = 0; i < marketAddresses.length; i++) {
            bytes32 marketKey = DataStore(dataStore).getMarketKey(marketAddresses[i]);
            MarketFactory.Market memory market = DataStore(dataStore).getMarket(marketKey);

            console.log("MARKET_TOKEN_ADDRESS=%s", market.marketToken);
            console.log("LONG_TOKEN_ADDRESS=%s", market.longToken);
            console.log("SHORT_TOKEN_ADDRESS=%s", market.shortToken);
            console.log("MARKET_STATUS=%s", uint256(market.status));
        }

        vm.stopBroadcast();
    }
}
