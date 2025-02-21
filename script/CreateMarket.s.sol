// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MarketFactory.sol";

contract CreateMarketScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketFactory = vm.envAddress("MARKET_FACTORY_ADDRESS");
        address longToken = vm.envAddress("WETH_ADDRESS");
        address shortToken = vm.envAddress("USDC_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        address marketToken = MarketFactory(marketFactory).createMarket(
            longToken,
            shortToken
        );

        console.log("MARKET_ADDRESS=%s", address(marketToken));
        
        vm.stopBroadcast();
    }
} 