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
import "../interfaces/IGTXOracleServiceManager.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wnt = vm.envAddress("WETH_ADDRESS");
        address oracle = vm.envAddress("GTXORACLE_SERVICE_MANAGER_ADDRESS");
        uint256 minBlockInterval = vm.envUint("MIN_BLOCK_INTERVAL");
        uint256 maxBlockInterval = vm.envUint("MAX_BLOCK_INTERVAL");
        // address dataStore = vm.envAddress("DATA_STORE_ADDRESS");
        // address marketFactory = vm.envAddress("MARKET_FACTORY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core storage
        DataStore dataStore = new DataStore();

        // Deploy market factory
        MarketFactory marketFactory = new MarketFactory(address(dataStore));

        // Deploy oracle
        // Oracle oracle = new Oracle(minBlockInterval, maxBlockInterval);

        // Oracle AVS with service manager
        IGTXOracleServiceManager(oracle).initialize(
            address(marketFactory), minBlockInterval, maxBlockInterval
        );

        // Deploy market handler
        MarketHandler marketHandler = new MarketHandler(address(dataStore), address(oracle));

        // Deploy vaults
        OrderVault orderVault = new OrderVault();
        DepositVault depositVault = new DepositVault();

        // Deploy position handler
        PositionHandler positionHandler =
            new PositionHandler(address(dataStore), address(oracle), address(marketHandler));

        marketHandler.setPositionHandler(address(positionHandler));

        // Deploy handlers
        OrderHandler orderHandler = new OrderHandler(
            address(dataStore),
            address(orderVault),
            address(wnt),
            address(oracle),
            address(positionHandler),
            address(marketHandler)
        );

        positionHandler.setOrderHandler(address(orderHandler));

        DepositHandler depositHandler = new DepositHandler(
            address(dataStore), address(depositVault), address(marketHandler), address(wnt)
        );

        // Deploy router
        Router router = new Router(
            address(dataStore),
            address(depositHandler),
            address(0), // withdrawHandler - to be added later
            address(orderHandler),
            address(wnt),
            address(positionHandler),
            address(marketFactory),
            address(oracle)
        );

        console.log("DATA_STORE_ADDRESS=%s", address(dataStore));
        console.log("MARKET_FACTORY_ADDRESS=%s", address(marketFactory));
        console.log("ORACLE_ADDRESS=%s", address(oracle));
        console.log("ORDER_VAULT_ADDRESS=%s", address(orderVault));
        console.log("DEPOSIT_VAULT_ADDRESS=%s", address(depositVault));
        console.log("ORDER_HANDLER_ADDRESS=%s", address(orderHandler));
        console.log("POSITION_HANDLER_ADDRESS=%s", address(positionHandler));
        console.log("MARKET_HANDLER_ADDRESS=%s", address(marketHandler));
        console.log("DEPOSIT_HANDLER_ADDRESS=%s", address(depositHandler));
        console.log("ROUTER_ADDRESS=%s", address(router));

        vm.stopBroadcast();
    }
}
