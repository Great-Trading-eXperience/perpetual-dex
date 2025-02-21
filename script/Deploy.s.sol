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
        address wnt = vm.envAddress("WETH_ADDRESS");
        uint256 minBlockInterval = vm.envUint("MIN_BLOCK_INTERVAL");
        uint256 maxBlockInterval = vm.envUint("MAX_BLOCK_INTERVAL");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy oracle
        Oracle oracle = new Oracle(
            minBlockInterval,
            maxBlockInterval
        );

        // Deploy core storage
        DataStore dataStore = new DataStore();

        // Deploy market factory
        MarketFactory marketFactory = new MarketFactory(address(dataStore));

        // Deploy market handler
        MarketHandler marketHandler = new MarketHandler(
            address(dataStore),
            address(oracle)
        );

        // Deploy vaults
        OrderVault orderVault = new OrderVault();
        DepositVault depositVault = new DepositVault();

        // Deploy handlers
        OrderHandler orderHandler = new OrderHandler(
            address(orderVault),
            address(wnt)
        );
        
        DepositHandler depositHandler = new DepositHandler(
            address(dataStore),
            address(depositVault),
            address(marketHandler),
            address(wnt)
        );

        // Deploy router
        Router router = new Router(
            address(dataStore),
            address(depositHandler),
            address(0), // withdrawHandler - to be added later
            address(orderHandler),
            address(wnt)
        );

        console.log("ORACLE_ADDRESS=%s", address(oracle));
        console.log("DATA_STORE_ADDRESS=%s", address(dataStore));
        console.log("ORDER_VAULT_ADDRESS=%s", address(orderVault));
        console.log("DEPOSIT_VAULT_ADDRESS=%s", address(depositVault));
        console.log("ORDER_HANDLER_ADDRESS=%s", address(orderHandler));
        console.log("DEPOSIT_HANDLER_ADDRESS=%s", address(depositHandler));
        console.log("MARKET_FACTORY_ADDRESS=%s", address(marketFactory));
        console.log("ROUTER_ADDRESS=%s", address(router));

        vm.stopBroadcast();
    }
} 