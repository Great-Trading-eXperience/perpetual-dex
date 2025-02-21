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
        uint256 depositKey = vm.envUint("DEPOSIT_KEY");

        // Start broadcasting keeper's transactions
        vm.startBroadcast(keeperPrivateKey);

        // Get deposit info for logging
        DepositHandler.Deposit memory deposit = DataStore(dataStore).getDeposit(depositKey);
        
        // Log deposit details before execution
        console.log("Executing deposit with key:", depositKey);
        console.log("Deposit account:", deposit.account);
        console.log("Long token amount:", deposit.initialLongTokenAmount);
        console.log("Short token amount:", deposit.initialShortTokenAmount);
        console.log("Execution fee:", deposit.executionFee);

        // Execute the deposit
        DepositHandler(depositHandler).executeDeposit(depositKey);

        console.log("Deposit executed successfully");
        console.log("Keeper received execution fee:", deposit.executionFee);

        uint256 balanceOfMarketToken = IERC20(deposit.marketToken).balanceOf(deposit.receiver);

        console.log("Balance of market token: %s", balanceOfMarketToken);

        vm.stopBroadcast();
    }
} 