// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Router.sol";
import "../src/OrderHandler.sol";
import "../src/DataStore.sol";
import "../src/Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidatePositionScript is Script {
    function run() external {
        uint256 liquidatorPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address dataStore = vm.envAddress("DATA_STORE_ADDRESS");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address market = vm.envAddress("MARKET_ADDRESS");
        address wnt = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        // Set oracle prices first
        vm.startBroadcast(liquidatorPrivateKey);

        // Setup oracle prices for execution
        address[] memory tokens = new address[](2);
        tokens[0] = wnt;
        tokens[1] = usdc;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](2);
        
        uint256 wntPrice = 2700 * 10**18;  // $2700 per WNT
        uint256 usdcPrice = 1 * 10**18;    // $1 per USDC

        // Get current block and timestamp
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;

        // Sign WNT price
        bytes32 wntMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(wnt, wntPrice, timestamp, blockNumber))
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(liquidatorPrivateKey, wntMessageHash);
        signedPrices[0] = Oracle.SignedPrice({
            price: wntPrice,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: abi.encodePacked(r1, s1, v1)
        });

        // Sign USDC price
        bytes32 usdcMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(usdc, usdcPrice, timestamp, blockNumber))
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(liquidatorPrivateKey, usdcMessageHash);
        signedPrices[1] = Oracle.SignedPrice({
            price: usdcPrice,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: abi.encodePacked(r2, s2, v2)
        });

        // Set prices in oracle
        Oracle(oracle).setPrices(tokens, signedPrices);

        // Construct position key
        bytes32 positionKey = keccak256(
            abi.encodePacked(
                vm.addr(userPrivateKey),
                market,
                wnt
            )
        );

        // Get order details before execution
        PositionHandler.Position memory position = DataStore(dataStore).getPosition(positionKey);
        
        console.log("account", position.account);
        console.log("market", position.market);

        // Liquidate position
        Router(router).liquidatePosition(PositionHandler.LiquidatePositionParams({
            account: position.account,
            market: position.market,
            collateralToken: position.collateralToken
        }));

        // Get liquidator's execution fee
        uint256 liquidatorBalance = IERC20(wnt).balanceOf(vm.addr(liquidatorPrivateKey));
        console.log("Liquidator received liquidation fee:", liquidatorBalance);

        position = DataStore(dataStore).getPosition(positionKey);

        console.log("Position size in USD:", position.sizeInUsd);
        console.log("Position collateral:", position.collateralAmount);

        vm.stopBroadcast();
    }
} 