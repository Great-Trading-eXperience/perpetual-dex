// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "forge-std/Script.sol";
import "../src/curator/AssetVault.sol";

contract DepositToCuratorVaults is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address vault1 = vm.envAddress("VAULT_1");
        address vault2 = vm.envAddress("VAULT_2");
        address vault3 = vm.envAddress("VAULT_3");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address wnt = vm.envAddress("WETH_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Transfer WNT to vaults for execution fees
        IERC20(wnt).transfer(vault1, 1 ether);
        IERC20(wnt).transfer(vault2, 1 ether);
        IERC20(wnt).transfer(vault3, 1 ether);

        console.log("Deposited 1 WNT to each vault");

        // Get the asset token from the vault
        address asset = AssetVault(vault1).asset();

        console.log("Asset: %s", asset);
        
        // Approve USDC spending
        IERC20(asset).approve(vault1, 10000000000);

        // Deposit USDC to vault 1
        AssetVault(vault1).deposit(10000000000);

        // Then deposit USDC to each vault
        // Vault 2
        IERC20(usdc).approve(vault2, 10000 * 10**6);
        AssetVault(vault2).deposit(10000 * 10**6);

        // Vault 3
        IERC20(usdc).approve(vault3, 10000 * 10**6);
        AssetVault(vault3).deposit(10000 * 10**6);

        vm.stopBroadcast();

        console.log("Deposited 10,000 USDC to each vault");
        console.log("Vault1 USDC balance: %s", IERC20(usdc).balanceOf(vault1) / 1e6);
        console.log("Vault2 USDC balance: %s", IERC20(usdc).balanceOf(vault2) / 1e6);
        console.log("Vault3 USDC balance: %s", IERC20(usdc).balanceOf(vault3) / 1e6);
        console.log("Vault1 WETH balance: %s", IERC20(weth).balanceOf(vault1) / 1e18);
        console.log("Vault2 WETH balance: %s", IERC20(weth).balanceOf(vault2) / 1e18);
        console.log("Vault3 WETH balance: %s", IERC20(weth).balanceOf(vault3) / 1e18);
    }
} 