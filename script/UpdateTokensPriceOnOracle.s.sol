// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Oracle.sol";

contract UpdateOraclePrices is Script {
    Oracle public oracle;
    uint256 public deployerPrivateKey;
    uint256 public signerPrivateKey;

    function setUp() public {
        // Load private keys from environment
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        signerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Oracle contract address should be set in environment
        oracle = Oracle(vm.envAddress("GTX_ORACLE_SERVICE_MANAGER_ADDRESS"));
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // Get token addresses
        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address pepe = vm.envAddress("PEPE_ADDRESS");
        address trump = vm.envAddress("TRUMP_ADDRESS");
        address link = vm.envAddress("LINK_ADDRESS");
        address doge = vm.envAddress("DOGE_ADDRESS");

        uint256 wethPrice = 2000 * 1e18 + (uint256(keccak256(abi.encodePacked(block.timestamp))) % (200 * 1e18)) - (100 * 1e18);
        Oracle(oracle).setPrice(
            weth,
            wethPrice
        );

        uint256 wbtcPrice = 42000 * 1e18 + (uint256(keccak256(abi.encodePacked(block.timestamp + 1))) % (4200 * 1e18)) - (2100 * 1e18);
        Oracle(oracle).setPrice(
            wbtc, 
            wbtcPrice
        );

        // USDC should stay stable at $1
        Oracle(oracle).setPrice(
            usdc,
            1e18
        );

        uint256 pepePrice = 1e14 + (uint256(keccak256(abi.encodePacked(block.timestamp + 2))) % 1e13) - (5e12);
        Oracle(oracle).setPrice(
            pepe,
            pepePrice
        );

        uint256 dogePrice = 10 * 1e16 + (uint256(keccak256(abi.encodePacked(block.timestamp + 3))) % (1e16)) - (5e15);
        Oracle(oracle).setPrice(
            doge,
            dogePrice
        );

        uint256 trumpPrice = 5 * 1e16 + (uint256(keccak256(abi.encodePacked(block.timestamp + 4))) % (5e15)) - (25e14);
        Oracle(oracle).setPrice(
            trump,
            trumpPrice
        );

        uint256 linkPrice = 15 * 1e18 + (uint256(keccak256(abi.encodePacked(block.timestamp + 5))) % (15e17)) - (75e16);
        Oracle(oracle).setPrice(
            link,
            linkPrice
        );

        vm.stopBroadcast();
    }
}