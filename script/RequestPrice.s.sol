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

        // Get token addresses from environment variables
        address wethAddress = vm.envAddress("WETH_ADDRESS");
        address wbtcAddress = vm.envAddress("WBTC_ADDRESS");
        address pepeAddress = vm.envAddress("PEPE_ADDRESS");
        address trumpAddress = vm.envAddress("TRUMP_ADDRESS");
        address dogeAddress = vm.envAddress("DOGE_ADDRESS");
        address linkAddress = vm.envAddress("LINK_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // request price tasks for all tokens
        address serviceManager = vm.envAddress("GTX_ORACLE_SERVICE_MANAGER_ADDRESS");
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(wethAddress);
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(wbtcAddress);
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(pepeAddress);
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(trumpAddress);
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(dogeAddress);
        IGTXOracleServiceManager(serviceManager).requestOraclePriceTask(linkAddress);

        vm.stopBroadcast();
    }
}
