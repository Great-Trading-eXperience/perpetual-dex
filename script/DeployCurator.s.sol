// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/curator/AssetVault.sol";
import "../src/curator/VaultFactory.sol";
import "../src/curator/CuratorRegistry.sol";
import "../src/mocks/MockCurator.sol";
import "../src/curator/CuratorFactory.sol";
import "../src/curator/Curator.sol";

contract DeployCurator is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 curator1PrivateKey = vm.envUint("PRIVATE_KEY_CURATOR_1");
        uint256 curator2PrivateKey = vm.envUint("PRIVATE_KEY_CURATOR_2");
        uint256 curator3PrivateKey = vm.envUint("PRIVATE_KEY_CURATOR_3");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");
        address depositHandler = vm.envAddress("DEPOSIT_HANDLER_ADDRESS");
        address depositVault = vm.envAddress("DEPOSIT_VAULT_ADDRESS");
        address withdrawVault = vm.envAddress("WITHDRAW_VAULT_ADDRESS");
        address marketFactory = vm.envAddress("MARKET_FACTORY_ADDRESS");
        address curatorRegistry = vm.envAddress("CURATOR_REGISTRY_ADDRESS");
        address curatorFactory = vm.envAddress("CURATOR_FACTORY_ADDRESS");
        address vaultFactory = vm.envAddress("VAULT_FACTORY_ADDRESS");
        address wnt = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address wethUsdcMarket = vm.envAddress("WETH_USDC_MARKET_ADDRESS");
        address wbtcUsdcMarket = vm.envAddress("WBTC_USDC_MARKET_ADDRESS");
        address pepeUsdcMarket = vm.envAddress("PEPE_USDC_MARKET_ADDRESS");
        address dogeUsdcMarket = vm.envAddress("DOGE_USDC_MARKET_ADDRESS");
        address trumpUsdcMarket = vm.envAddress("TRUMP_USDC_MARKET_ADDRESS");
        address linkUsdcMarket = vm.envAddress("LINK_USDC_MARKET_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy curator implementation and factory
        MockCurator curatorImplementation = new MockCurator();

        // Deploy vault implementation and factory
        AssetVault vaultImplementation = new AssetVault(
            router,
            dataStore,
            depositHandler,
            depositVault,
            withdrawVault,
            marketFactory,
            wnt
        );

        // Add curators to registry
        CuratorRegistry(curatorRegistry).addCurator(
            vm.addr(curator1PrivateKey),
            "Test Curator 1",
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQVh3inqKyGGbBhoPo6jBMzGY5eIgx9fCJj7E6fORXA-0SngqoiOsgiZ3CGWbxKqXXVmrg&usqp=CAU"
        );

        CuratorRegistry(curatorRegistry).addCurator(
            vm.addr(curator2PrivateKey), 
            "Test Curator 2",
            "https://www.sevell.com/wp-content/uploads/2024/07/peloton-logo-red.png"
        );

        CuratorRegistry(curatorRegistry).addCurator(
            vm.addr(curator3PrivateKey), 
            "Test Curator 3",
            "https://images-platform.99static.com//7wcGDCCvD13MOorSSdbhqGNU3qk=/256x2289:756x2789/fit-in/590x590/99designs-contests-attachments/70/70438/attachment_70438547"
        );

        vm.stopBroadcast();

        // Create curator contracts and vaults
        vm.startBroadcast(curator1PrivateKey);
        address curatorContract1 = CuratorFactory(curatorFactory).deployCuratorContract(
            "Curator One",
            "ipfs://curator1",
            500  // 5% fee
        );
        
        AssetVault vault1 = AssetVault(VaultFactory(vaultFactory).createVault(
            curatorContract1,  // Use curator contract address
            usdc,
            "Blue Chip Portfolio",
            "vBLUE",
            marketFactory,
            wnt
        ));

        // Call addMarket through the curator contract
        Curator(curatorContract1).addMarketToVault(
            address(vault1),
            wethUsdcMarket,
            4500
        );
        Curator(curatorContract1).addMarketToVault(
            address(vault1),
            linkUsdcMarket,
            3000
        );
        Curator(curatorContract1).addMarketToVault(
            address(vault1),
            wbtcUsdcMarket,
            2500
        );
        vm.stopBroadcast();

        // Repeat for other curators...
        vm.startBroadcast(curator2PrivateKey);
        address curatorContract2 = CuratorFactory(curatorFactory).deployCuratorContract(
            "Curator Two",
            "ipfs://curator2",
            500
        );
        
        AssetVault vault2 = AssetVault(VaultFactory(vaultFactory).createVault(
            curatorContract2,
            usdc,
            "Major Assets",
            "vMAJOR",
            marketFactory,
            wnt
        ));

        Curator(curatorContract2).addMarketToVault(
            address(vault2),
            wethUsdcMarket,
            5000
        );
        Curator(curatorContract2).addMarketToVault(
            address(vault2),
            linkUsdcMarket,
            3000
        );
        Curator(curatorContract2).addMarketToVault(
            address(vault2),
            dogeUsdcMarket,
            2000
        );
        vm.stopBroadcast();

        // Create vault for Curator 3
        vm.startBroadcast(curator3PrivateKey);
        address curatorContract3 = CuratorFactory(curatorFactory).deployCuratorContract(
            "Curator Three",
            "ipfs://curator3",
            500
        );

        AssetVault vault3 = AssetVault(VaultFactory(vaultFactory).createVault(
            curatorContract3,
            usdc,
            "Mixed Portfolio",
            "vMIX", 
            marketFactory,
            wnt
        ));

        Curator(curatorContract3).addMarketToVault(
            address(vault3),
            wethUsdcMarket,
            4000
        );
        Curator(curatorContract3).addMarketToVault(
            address(vault3),
            linkUsdcMarket,
            2000
        );
        MockCurator(curatorContract3).addMarketToVault(
            address(vault3),
            trumpUsdcMarket,
            2000
        );
        MockCurator(curatorContract3).addMarketToVault(
            address(vault3),
            pepeUsdcMarket,
            2000
        );
        vm.stopBroadcast();

        // Log deployed addresses
        console.log("CURATOR_CONTRACT_1=%s", address(curatorContract1));
        console.log("CURATOR_CONTRACT_2=%s", address(curatorContract2));
        console.log("CURATOR_CONTRACT_3=%s", address(curatorContract3));

        console.log("VAULT_1=%s", address(vault1));
        console.log("VAULT_2=%s", address(vault2));
        console.log("VAULT_3=%s", address(vault3));
    }
} 