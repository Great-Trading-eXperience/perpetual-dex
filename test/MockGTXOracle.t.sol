// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../test/mocks/MockGTXOracle.sol";
import "../interfaces/IGTXOracleServiceManager.sol";
import "../reclaim/Reclaim.sol";

contract MockGTXOracleTest is Test {
    MockGTXOracleServiceManager public mockOracle;

    function setUp() public {
        // Deploy the mock oracle
        mockOracle = new MockGTXOracleServiceManager();
    }

    function testRequestNewOracleTask() public {
        // Define oracle source data
        address tokenAddress = 0x1234567890123456789012345678901234567890;
        string memory tokenPair = "ETH/USDT";
        MockGTXOracleServiceManager.Source[] memory sources = new MockGTXOracleServiceManager.Source[](2);
        sources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "ETHUSDT", network: ""});
        sources[1] = IGTXOracleServiceManager.Source({name: "dexscreener", identifier: "0x...", network: "ethereum"});

        // Request new oracle task
        uint32 taskIndex = mockOracle.requestNewOracleTask(tokenAddress, tokenPair, sources);

        // Verify the task index
        assertEq(taskIndex, 0);
    }

    function testRespondToOracleTask() public {
        // Define oracle task data
        address tokenAddress = 0x1234567890123456789012345678901234567890;
        uint256 price = 123456789; // Price with 8 decimals
        string memory tokenPair = "ETH/USDT";

        MockGTXOracleServiceManager.Source[] memory sources = new MockGTXOracleServiceManager.Source[](1);
        sources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "ETHUSDT", network: ""});

        uint32 taskIndex = mockOracle.requestNewOracleTask(tokenAddress, tokenPair, sources);

        Reclaim.Proof memory mockProof = Reclaim.Proof({
            claimInfo: Claims.ClaimInfo({provider: "MockProvider", parameters: "{}", context: "TestContext"}),
            signedClaim: Claims.SignedClaim({
                claim: Claims.CompleteClaimData({
                    identifier: keccak256(abi.encodePacked("mock")),
                    owner: address(this),
                    timestampS: uint32(block.timestamp),
                    epoch: 1
                }),
                signatures: new bytes[](0)
            })
        });

        // Respond to oracle task
        MockGTXOracleServiceManager.OracleTask memory task = IGTXOracleServiceManager.OracleTask({
            tokenAddress: tokenAddress,
            taskCreatedBlock: uint32(block.number),
            isNewData: true,
            tokenPair: tokenPair,
            sources: sources
        });

        mockOracle.respondToOracleTask(task, price, taskIndex, bytes(""), mockProof);

        // Retrieve and verify the oracle price data
        uint256 retrievedPrice = mockOracle.getPrice(tokenAddress);
        assertEq(retrievedPrice, price);
    }

    function testequestPriceOracleTask() public {
        // Define oracle task data
        address tokenAddress = 0x1234567890123456789012345678901234567890;
        uint256 price = 123456789; // Price with 8 decimals
        string memory tokenPair = "ETH/USDT";

        MockGTXOracleServiceManager.Source[] memory sources = new MockGTXOracleServiceManager.Source[](1);
        sources[0] = IGTXOracleServiceManager.Source({name: "binance", identifier: "ETHUSDT", network: ""});

        uint32 taskIndex = mockOracle.requestNewOracleTask(tokenAddress, tokenPair, sources);

        Reclaim.Proof memory mockProof = Reclaim.Proof({
            claimInfo: Claims.ClaimInfo({provider: "MockProvider", parameters: "{}", context: "TestContext"}),
            signedClaim: Claims.SignedClaim({
                claim: Claims.CompleteClaimData({
                    identifier: keccak256(abi.encodePacked("mock")),
                    owner: address(this),
                    timestampS: uint32(block.timestamp),
                    epoch: 1
                }),
                signatures: new bytes[](0)
            })
        });

        // Respond to oracle task
        MockGTXOracleServiceManager.OracleTask memory task = IGTXOracleServiceManager.OracleTask({
            tokenAddress: tokenAddress,
            taskCreatedBlock: uint32(block.number),
            isNewData: true,
            tokenPair: tokenPair,
            sources: sources
        });

        mockOracle.respondToOracleTask(task, price, taskIndex, bytes(""), mockProof);

        // Retrieve and verify the oracle price data
        uint256 retrievedPrice = mockOracle.getPrice(tokenAddress);
        assertEq(retrievedPrice, price);

        // Request oracle task
        price = 133446789; // Price with 8 decimals
        taskIndex = mockOracle.requestOraclePriceTask(tokenAddress);
        mockOracle.respondToOracleTask(task, price, taskIndex, bytes(""), mockProof);
        // Retrieve and verify the oracle price data
        retrievedPrice = mockOracle.getPrice(tokenAddress);
        assertEq(retrievedPrice, price);
    }
}
