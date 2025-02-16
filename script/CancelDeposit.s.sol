// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Router.sol";

contract CancelDepositScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        uint256 depositKey = vm.envUint("DEPOSIT_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        Router(router).cancelDeposit(depositKey);

        console.log("Deposit %s cancelled successfully", depositKey);

        vm.stopBroadcast();
    }
} 