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
        address longToken = vm.envAddress("WBTC_ADDRESS");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        MarketFactory.Market memory market =
            DataStore(dataStore).getMarket(keccak256(abi.encodePacked(longToken, shortToken)));

        console.log("MARKET_TOKEN_ADDRESS=%s", market.marketToken);
        console.log("LONG_TOKEN_ADDRESS=%s", market.longToken);
        console.log("SHORT_TOKEN_ADDRESS=%s", market.shortToken);
        console.log("MARKET_STATUS=%s", uint256(market.status));

        vm.stopBroadcast();
    }
}
