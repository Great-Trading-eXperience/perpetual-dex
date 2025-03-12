// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/DepositHandler.sol";
import "../src/DataStore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteDepositScript is Script {
    function run() external {
        uint256 keeperPrivateKey = vm.envUint("PRIVATE_KEY");
        address depositHandler = vm.envAddress("DEPOSIT_HANDLER_ADDRESS");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");

        // Start broadcasting keeper's transactions
        vm.startBroadcast(keeperPrivateKey);

        // Get total number of deposits
        uint256 depositCount = DataStore(dataStore).getNonce(DataStore.TransactionType.Deposit);
        console.log("Total deposits to execute: %s", depositCount);

        // Execute each valid deposit
        for (uint256 i = 0; i < depositCount; i++) {
            DepositHandler.Deposit memory deposit = DataStore(dataStore).getDeposit(i);
            
            // Skip empty/invalid deposits
            if (deposit.account == address(0) || deposit.marketToken == address(0)) {
                console.log("Skipping invalid deposit %s", i);
                continue;
            }

            console.log("\nExecuting deposit with key: %s", i);
            console.log("Deposit account:", deposit.account);
            console.log("Long token amount:", deposit.initialLongTokenAmount);
            console.log("Short token amount:", deposit.initialShortTokenAmount);
            console.log("Execution fee:", deposit.executionFee);

            try DepositHandler(depositHandler).executeDeposit(i) {
                console.log("Deposit executed successfully");
                
                // Log execution fee received
                uint256 keeperBalance = address(msg.sender).balance;
                console.log("Keeper received execution fee: %s", keeperBalance);

                // Log market token balance
                uint256 balanceOfMarketToken = IERC20(deposit.marketToken).balanceOf(deposit.receiver);
                console.log("Balance of market token: %s", balanceOfMarketToken);
            } catch {
                console.log("Failed to execute deposit %s", i);
            }
        }

        vm.stopBroadcast();
    }
}