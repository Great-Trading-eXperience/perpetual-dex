// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Router.sol";

contract CancelOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        uint256 orderKey = vm.envUint("ORDER_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        Router(router).cancelOrder(orderKey);

        console.log("Order %s cancelled successfully", orderKey);

        vm.stopBroadcast();
    }
} 