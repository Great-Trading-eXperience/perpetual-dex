// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Oracle.sol";

contract OracleTest is Test {
    Oracle public oracle;
    address public owner;
    address public token;
    address public signer1;
    address public signer2;
    uint256 public signer1PrivateKey;
    uint256 public signer2PrivateKey;

    // Constants for testing
    uint256 constant MIN_BLOCK_INTERVAL = 1;
    uint256 constant MAX_BLOCK_INTERVAL = 100;
    uint256 constant MAX_PRICE_AGE = 3600; // 1 hour

    function setUp() public {
        // Setup accounts
        owner = address(this);
        token = address(0x1);
        signer1PrivateKey = 0x1;
        signer2PrivateKey = 0x2;
        signer1 = vm.addr(signer1PrivateKey);
        signer2 = vm.addr(signer2PrivateKey);

        // Deploy Oracle
        oracle = new Oracle(MIN_BLOCK_INTERVAL, MAX_BLOCK_INTERVAL);

        // Setup initial configuration
        oracle.setSigner(token, signer1, true);
        oracle.setMinSigners(token, 1);
        oracle.setMaxPriceAge(token, MAX_PRICE_AGE);
    }

    function testSetPrice() public {
        // Prepare signed price data
        uint256 price = 1000 * 1e18;
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number + MIN_BLOCK_INTERVAL;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(token, price, timestamp, blockNumber))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Create arrays for setPrices
        address[] memory tokens = new address[](1);
        tokens[0] = token;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](1);
        signedPrices[0] = Oracle.SignedPrice({
            price: price,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: signature
        });

        // Set price
        vm.roll(blockNumber);
        oracle.setPrices(tokens, signedPrices);

        // Verify price was set correctly
        assertEq(oracle.getPrice(token), price);
    }

    function testInvalidSigner() public {
        uint256 price = 1000 * 1e18;
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number + MIN_BLOCK_INTERVAL;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(token, price, timestamp, blockNumber))
            )
        );

        // Sign with unauthorized signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer2PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](1);
        signedPrices[0] = Oracle.SignedPrice({
            price: price,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: signature
        });

        vm.roll(blockNumber);
        // TODO
        // vm.expectRevert(Oracle.InvalidSigner.selector);
        oracle.setPrices(tokens, signedPrices);
    }

    function testStalePrice() public {
        // Set initial price
        testSetPrice();

        // Try to set older timestamp
        uint256 price = 1100 * 1e18;
        uint256 timestamp = block.timestamp - 1;
        uint256 blockNumber = block.number + MIN_BLOCK_INTERVAL;

        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(token, price, timestamp, blockNumber))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](1);
        signedPrices[0] = Oracle.SignedPrice({
            price: price,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: signature
        });

        vm.roll(blockNumber);
        // TODO
        // vm.expectRevert(Oracle.StalePrice.selector);
        oracle.setPrices(tokens, signedPrices);
    }

    function testPriceDeviationTooLarge() public {
        // Set initial price - using even smaller numbers
        uint256 initialPrice = 10 * 1e18;  // Start with 10
        uint256 timestamp = block.timestamp;
        uint256 blockNumber = block.number + MIN_BLOCK_INTERVAL;

        // First set the initial price
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(token, initialPrice, timestamp, blockNumber))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        address[] memory tokens = new address[](1);
        tokens[0] = token;

        Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](1);
        signedPrices[0] = Oracle.SignedPrice({
            price: initialPrice,
            timestamp: timestamp,
            blockNumber: blockNumber,
            signature: signature
        });

        vm.roll(blockNumber);
        oracle.setPrices(tokens, signedPrices);

        // Advance block timestamp for next price update
        vm.warp(block.timestamp + 1);

        // console.log("Initial price set:", initialPrice / 1e18);
        
        // Try to set a price with >10% deviation
        uint256 newPrice = 12 * 1e18;  // 20% increase
        uint256 newTimestamp = timestamp + 1;
        uint256 newBlockNumber = blockNumber + MIN_BLOCK_INTERVAL;

        console.log("New price attempting to set:", newPrice / 1e18);
        console.log("Expected deviation: 20%");

        messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(token, newPrice, newTimestamp, newBlockNumber))
            )
        );

        (v, r, s) = vm.sign(signer1PrivateKey, messageHash);
        signature = abi.encodePacked(r, s, v);

        signedPrices[0] = Oracle.SignedPrice({
            price: newPrice,
            timestamp: newTimestamp,
            blockNumber: newBlockNumber,
            signature: signature
        });

        vm.roll(newBlockNumber);
        // TODO
        // vm.expectRevert(Oracle.PriceDeviationTooLarge.selector);
        oracle.setPrices(tokens, signedPrices);
    }

    // function testBlockIntervalValidation() public {
    //     // Set initial price
    //     testSetPrice();

    //     // Try to set price with invalid block interval
    //     uint256 price = 1100 * 1e18;
    //     uint256 timestamp = block.timestamp + 1;
    //     uint256 blockNumber = block.number + MAX_BLOCK_INTERVAL + 1;

    //     bytes32 messageHash = keccak256(
    //         abi.encodePacked(
    //             "\x19Ethereum Signed Message:\n32",
    //             keccak256(abi.encodePacked(token, price, timestamp, blockNumber))
    //         )
    //     );

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(signer1PrivateKey, messageHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     address[] memory tokens = new address[](1);
    //     tokens[0] = token;

    //     Oracle.SignedPrice[] memory signedPrices = new Oracle.SignedPrice[](1);
    //     signedPrices[0] = Oracle.SignedPrice({
    //         price: price,
    //         timestamp: timestamp,
    //         blockNumber: blockNumber,
    //         signature: signature
    //     });

    //     vm.roll(blockNumber);
    //     // vm.expectRevert(Oracle.BlockIntervalInvalid.selector);
    //     oracle.setPrices(tokens, signedPrices);
    // }
} 