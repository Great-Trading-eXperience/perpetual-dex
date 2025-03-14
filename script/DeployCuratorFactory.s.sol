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
import "../interfaces/IGTXOracleServiceManager.sol";

contract DeployCuratorFactoryScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address wnt = vm.envAddress("WETH_ADDRESS");
        address dataStoreAddress = vm.envAddress("DATA_STORE_ADDRESS");
        address marketFactoryAddress = vm.envAddress("MARKET_FACTORY_ADDRESS");
        address depositVaultAddress = vm.envAddress("DEPOSIT_VAULT_ADDRESS");
        address withdrawVaultAddress = vm.envAddress("WITHDRAW_VAULT_ADDRESS");
        address depositHandlerAddress = vm.envAddress("DEPOSIT_HANDLER_ADDRESS");
        address routerAddress = vm.envAddress("ROUTER_ADDRESS");
        address curatorRegistryAddress = vm.envAddress("CURATOR_REGISTRY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy currator
        Curator curatorImplementation = new MockCurator();
        CuratorRegistry registry = new CuratorRegistry();
        CuratorFactory factory =
            new CuratorFactory(address(curatorImplementation), address(registry));
        AssetVault assetVault = new AssetVault(
            routerAddress,
            dataStoreAddress,
            depositHandlerAddress,
            depositVaultAddress,
            withdrawVaultAddress,
            marketFactoryAddress,
            wnt
        );
        VaultFactory vaultFactory = new VaultFactory(
            address(assetVault),
            curatorRegistryAddress,
            dataStoreAddress,
            routerAddress,
            depositHandlerAddress,
            depositVaultAddress,
            withdrawVaultAddress
        );

        console.log("CURATOR_REGISTRY_ADDRESS=%s", address(registry));
        console.log("CURATOR_FACTORY_ADDRESS=%s", address(factory));
        console.log("VAULT_FACTORY_ADDRESS=%s", address(vaultFactory));

        vm.stopBroadcast();
    }
}
