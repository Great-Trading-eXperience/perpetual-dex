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
import "../src/WithdrawVault.sol";
import "../src/MarketToken.sol";
import "../src/curator/CuratorRegistry.sol";
import "../src/curator/CuratorFactory.sol";
import "../src/curator/AssetVault.sol";
import "../src/mocks/MockCurator.sol";
import "../src/curator/VaultFactory.sol";

contract DeployCoreScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wnt = vm.envAddress("WETH_ADDRESS");
        uint256 minBlockInterval = vm.envUint("MIN_BLOCK_INTERVAL");
        uint256 maxBlockInterval = vm.envUint("MAX_BLOCK_INTERVAL");
        uint256 maxPriceAge = vm.envUint("MAX_PRICE_AGE");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy core storage
        DataStore dataStore = new DataStore();

        // Deploy market factory
        MarketFactory marketFactory = new MarketFactory(address(dataStore));

        // Deploy oracle
        // 1. Used for internal oracle
        // Oracle oracle = new Oracle(minBlockInterval, maxBlockInterval);

        // 2. Used for external oracle
        address oracleServiceManager = vm.envAddress("GTX_ORACLE_SERVICE_MANAGER_ADDRESS");
        IGTXOracleServiceManager(oracleServiceManager).initialize(
            address(marketFactory), minBlockInterval, maxBlockInterval, maxPriceAge
        );
        address oracle = oracleServiceManager;

        // Deploy market handler
        MarketHandler marketHandler = new MarketHandler(address(dataStore), address(oracle));

        // Deploy vaults
        OrderVault orderVault = new OrderVault();
        DepositVault depositVault = new DepositVault();
        WithdrawVault withdrawVault = new WithdrawVault();

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

        WithdrawHandler withdrawHandler = new WithdrawHandler(
            address(dataStore), address(withdrawVault), address(marketHandler), address(wnt)
        );

        // Deploy router
        Router router = new Router(
            address(dataStore),
            address(depositHandler),
            address(withdrawHandler),
            address(orderHandler),
            address(wnt),
            address(positionHandler),
            address(marketFactory),
            address(oracle)
        );

        // Deploy currator
        Curator curatorImplementation = new MockCurator();
        CuratorRegistry registry = new CuratorRegistry();
        CuratorFactory factory =
            new CuratorFactory(address(curatorImplementation), address(registry));
        AssetVault assetVault = new AssetVault(
            address(router),
            address(dataStore),
            address(depositHandler),
            address(depositVault),
            address(withdrawVault),
            address(marketFactory),
            address(wnt)
        );
        VaultFactory vaultFactory = new VaultFactory(
            address(assetVault),
            address(registry),
            address(dataStore),
            address(router),
            address(depositHandler),
            address(depositVault),
            address(withdrawVault)
        );

        console.log("DATA_STORE_ADDRESS=%s", address(dataStore));
        console.log("MARKET_FACTORY_ADDRESS=%s", address(marketFactory));
        console.log("ORACLE_ADDRESS=%s", address(oracle));
        console.log("ORDER_VAULT_ADDRESS=%s", address(orderVault));
        console.log("DEPOSIT_VAULT_ADDRESS=%s", address(depositVault));
        console.log("WITHDRAW_VAULT_ADDRESS=%s", address(withdrawVault));
        console.log("ORDER_HANDLER_ADDRESS=%s", address(orderHandler));
        console.log("POSITION_HANDLER_ADDRESS=%s", address(positionHandler));
        console.log("MARKET_HANDLER_ADDRESS=%s", address(marketHandler));
        console.log("DEPOSIT_HANDLER_ADDRESS=%s", address(depositHandler));
        console.log("WITHDRAW_HANDLER_ADDRESS=%s", address(withdrawHandler));
        console.log("MARKET_FACTORY_ADDRESS=%s", address(marketFactory));
        console.log("ROUTER_ADDRESS=%s", address(router));
        console.log("CURATOR_REGISTRY_ADDRESS=%s", address(registry));
        console.log("CURATOR_FACTORY_ADDRESS=%s", address(factory));
        console.log("VAULT_FACTORY_ADDRESS=%s", address(vaultFactory));

        vm.stopBroadcast();
    }
}
