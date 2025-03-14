// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../../interfaces/IGTXOracleServiceManager.sol";
import {Reclaim} from "../../reclaim/Reclaim.sol";

contract MockGTXOracleServiceManager is IGTXOracleServiceManager {
    address public constant CLAIM_OWNER = 0xfdE71B8a4f2D10DD2D210cf868BB437038548A39;
    uint32 public latestTaskNum;
    address public marketFactory;
    uint256 public minBlockInterval;
    uint256 public maxBlockInterval;
    uint256 public maxPriceAge;

    mapping(uint32 => bytes32) public allTaskHashes;
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;
    mapping(address => Price) public prices;
    mapping(address => Source[]) public sources;
    mapping(address => string) public pairs;

    function requestNewOracleTask(
        address _tokenAddress,
        address, /*_tokenAddress2*/
        string calldata _tokenPair,
        Source[] calldata _sources
    ) external returns (uint32 taskIndex) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_sources.length > 0, "Sources cannot be empty");

        sources[_tokenAddress] = _sources;
        pairs[_tokenAddress] = _tokenPair;
        emit OracleSourceCreated(_tokenAddress, _tokenPair, _sources, msg.sender);

        taskIndex = latestTaskNum;
        latestTaskNum = latestTaskNum + 1;
    }

    function requestOraclePriceTask(
        address _tokenAddress
    ) external returns (uint32 taskIndex) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(sources[_tokenAddress].length > 0, "Sources not registered");

        OracleTask memory newTask;
        newTask.tokenAddress = _tokenAddress;
        newTask.tokenPair = pairs[_tokenAddress];
        newTask.taskCreatedBlock = uint32(block.number);
        newTask.sources = sources[_tokenAddress];

        allTaskHashes[latestTaskNum] = keccak256(abi.encode(newTask));
        emit NewOracleTaskCreated(latestTaskNum, newTask);
        taskIndex = latestTaskNum;
        latestTaskNum = latestTaskNum + 1;
    }

    function respondToOracleTask(
        OracleTask calldata task,
        uint256 _price,
        uint32 referenceTaskIndex,
        bytes calldata signature,
        Reclaim.Proof calldata /*proof */
    ) external {
        // require(keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex], "Task mismatch");
        // require(allTaskResponses[msg.sender][referenceTaskIndex].length == 0, "Already responded");

        // if (proof.signedClaim.claim.owner != CLAIM_OWNER) {
        //     revert InvalidClaimOwner();
        // }

        prices[task.tokenAddress] = Price({
            value: _price,
            timestamp: block.timestamp,
            blockNumber: task.taskCreatedBlock,
            minBlockInterval: 0,
            maxBlockInterval: 0
        });

        allTaskResponses[msg.sender][referenceTaskIndex] = signature;

        emit OraclePriceUpdated(task.tokenAddress, task.tokenPair, _price, block.timestamp);
        emit OracleTaskResponded(referenceTaskIndex, task, msg.sender, signature);
    }

    function getPrice(
        address _tokenAddress
    ) external view override returns (uint256) {
        return prices[_tokenAddress].value;
    }

    function getSources(
        address _tokenAddress
    ) external view override returns (Source[] memory) {
        return sources[_tokenAddress];
    }

    function initialize(
        address _marketFactory,
        uint256 _minBlockInterval,
        uint256 _maxBlockInterval,
        uint256 _maxPriceAge
    ) external {
        marketFactory = _marketFactory;
        minBlockInterval = _minBlockInterval;
        maxBlockInterval = _maxBlockInterval;
        maxPriceAge = _maxPriceAge;

        emit Initialize(marketFactory);
    }

    function setPrice(address _tokenAddress, uint256 _price) external override {
        prices[_tokenAddress] = Price({
            value: _price,
            timestamp: block.timestamp,
            blockNumber: block.number,
            minBlockInterval: 0,
            maxBlockInterval: 0
        });

        emit OraclePriceUpdated(_tokenAddress, "", _price, block.timestamp);
    }
}
