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
        oracle = Oracle(vm.envAddress("ORACLE_ADDRESS"));
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // Setup weth token and signer
        address weth = vm.envAddress("WETH_ADDRESS"); // Replace with actual token address
        address usdc = vm.envAddress("USDC_ADDRESS"); // Replace with actual token address
        address signer = vm.addr(signerPrivateKey);
        
        // Create signed price update
       // Set initial prices (3000 USDC per 1 WETH)
        address[] memory tokens = new address[](2);
        tokens[0] = weth;
        tokens[1] = usdc; 

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](2);
        
        uint256 wethPrice = 3000 * 10 ** 18;
        uint256 usdcPrice = 1 * 10 ** 18;

        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number;

        // Sign and set price for WETH using the correct private key
        bytes32 wethMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(weth, wethPrice, block.timestamp, block.number))
            )
        );
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(deployerPrivateKey, wethMessageHash);
        signedPrices[0] = Oracle.SignedPrice({
            price: wethPrice,  // WETH price in USDC
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r1, s1, v1)
        });

        // Sign and set price for USDC using the correct private key
        bytes32 usdcMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(usdc, usdcPrice, block.timestamp, block.number))
            )
        );
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(deployerPrivateKey, usdcMessageHash);
        signedPrices[1] = Oracle.SignedPrice({
            price: usdcPrice,  // USDC price (1 USD)
            timestamp: block.timestamp,
            blockNumber: block.number,
            signature: abi.encodePacked(r2, s2, v2)
        });

        oracle.setPrices(tokens, signedPrices);
        vm.stopBroadcast();
    }
}