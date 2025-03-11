// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {MockToken} from "../test/mocks/MockToken.sol";

contract DeployMocks is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        console.log("Deployer Key:", deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        MockToken usdc = new MockToken("Mock USDC", "USDC", 6);
        MockToken weth = new MockToken("Mock WETH", "WETH", 18);
        MockToken wbtc = new MockToken("Mock WBTC", "WBTC", 8);
        MockToken pepe = new MockToken("Mock PEPE", "PEPE", 18);
        MockToken chainlink = new MockToken("Mock Chainlink", "LINK", 18);

        console.log("USDC_ADDRESS=%s", address(usdc));
        console.log("WETH_ADDRESS=%s", address(weth));
        console.log("WBTC_ADDRESS=%s", address(wbtc));
        console.log("PEPE_ADDRESS=%s", address(pepe));
        console.log("CHAINLINK_ADDRESS=%s", address(chainlink));

        vm.stopBroadcast();
    }
}
