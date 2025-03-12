// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/WithdrawHandler.sol";
import "../src/DataStore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteWithdrawScript is Script {
    function run() external {
        uint256 keeperPrivateKey = vm.envUint("PRIVATE_KEY");
        address withdrawHandler = vm.envAddress("WITHDRAW_HANDLER_ADDRESS");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");

        // Start broadcasting keeper's transactions
        vm.startBroadcast(keeperPrivateKey);

        // Get total number of withdraws
        uint256 withdrawCount = DataStore(dataStore).getNonce(DataStore.TransactionType.Withdraw);
        
        console.log("Total withdraws to execute:", withdrawCount);

        // Execute all withdraws
        for(uint256 i = 0; i < withdrawCount; i++) {
            // Get withdraw info for logging
            WithdrawHandler.Withdraw memory withdraw = DataStore(dataStore).getWithdraw(i);
            
            // Log withdraw details before execution
            console.log("\nExecuting withdraw with key:", i);
            console.log("Withdraw account:", withdraw.account);
            console.log("Market token amount:", withdraw.marketTokenAmount);
            console.log("Long token amount:", withdraw.longTokenAmount);
            console.log("Short token amount:", withdraw.shortTokenAmount);
            console.log("Execution fee:", withdraw.executionFee);

            try WithdrawHandler(withdrawHandler).executeWithdraw(i) {
                console.log("Withdraw executed successfully");
                console.log("Keeper received execution fee:", withdraw.executionFee);

                // Log token balances after withdraw
                uint256 longTokenBalance = IERC20(withdraw.longToken).balanceOf(withdraw.receiver);
                uint256 shortTokenBalance = IERC20(withdraw.shortToken).balanceOf(withdraw.receiver);
                console.log("Receiver long token balance: %s", longTokenBalance);
                console.log("Receiver short token balance: %s", shortTokenBalance);
            } catch {
                console.log("Failed to execute withdraw", i);
            }
        }

        vm.stopBroadcast();
    }
} 