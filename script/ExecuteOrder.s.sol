// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/OrderHandler.sol";
import "../src/DataStore.sol";
import "../src/Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecuteOrderScript is Script {
    function run() external {
        uint256 keeperPrivateKey = vm.envUint("PRIVATE_KEY");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");
        address orderHandler = vm.envAddress("ORDER_HANDLER_ADDRESS");
        // address oracle = vm.envAddress("ORACLE_ADDRESS");
        address oracleServiceManager = vm.envAddress("GTX_ORACLE_SERVICE_MANAGER_ADDRESS");
        address oracle = oracleServiceManager;
        address wnt = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Set oracle prices first
        vm.startBroadcast(keeperPrivateKey);

        // Setup oracle prices for execution
        address[] memory tokens = new address[](2);
        tokens[0] = wnt;
        tokens[1] = usdc;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](2);
        
        uint256 wntPrice = 3000 * 1e18;  // $3000 per WNT
        uint256 usdcPrice = 1 * 1e18;    // $1 per USDC

        // Get current block and timestamp
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;

        // Sign WNT price
        // Set prices in oracle
        Oracle(oracle).setPrice(tokens[0], wntPrice);
        Oracle(oracle).setPrice(tokens[1], usdcPrice);

        // Get total number of orders
        uint256 orderCount = DataStore(dataStore).getNonce(DataStore.TransactionType.Order);
        
        console.log("Total orders to execute:", orderCount);

        // Execute all orders
        for(uint256 i = 0; i < orderCount; i++) {
            // Get order details before execution
            OrderHandler.Order memory order = DataStore(dataStore).getOrder(i);
            
            console.log("\nExecuting order with key:", i);
            console.log("Order account:", order.account);
            console.log("Order size delta USD:", order.sizeDeltaUsd);
            console.log("Order collateral amount:", order.initialCollateralDeltaAmount);

            try OrderHandler(orderHandler).executeOrder(i) {
                console.log("Order executed successfully");

                // Get keeper's execution fee
                uint256 keeperBalance = IERC20(wnt).balanceOf(vm.addr(keeperPrivateKey));
                console.log("Keeper received execution fee:", keeperBalance);

                // Get position details after execution
                bytes32 positionKey = keccak256(
                    abi.encodePacked(
                        order.account,
                        order.marketToken,
                        order.initialCollateralToken
                    )
                );
                PositionHandler.Position memory position = DataStore(dataStore).getPosition(positionKey);
                
                console.log("Position size in USD:", position.sizeInUsd);
                console.log("Position collateral:", position.collateralAmount);
            } catch {
                console.log("Failed to execute order", i);
            }
        }

        vm.stopBroadcast();
    }
}
