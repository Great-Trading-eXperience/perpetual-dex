// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/console.sol";

contract Oracle is Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    // Structs
    struct Price {
        uint256 value;
        uint256 timestamp;
        uint256 blockNumber;
        uint256 minBlockInterval;
        uint256 maxBlockInterval;
    }

    struct SignedPrice {
        uint256 price;
        uint256 timestamp;
        uint256 blockNumber;
        bytes signature;
    }

    // State variables
    mapping(address => Price) public prices;
    mapping(address => mapping(address => bool)) public signers; // token => signer => isValid
    mapping(address => uint256) public minSigners; // Minimum signers required per token
    mapping(address => uint256) public maxPriceAge;
    
    uint256 public constant PRICE_PRECISION = 100;
    uint256 public constant MAX_PRICE_DEVIATION = 10; // 10% max deviation
    uint256 public constant SCALING_FACTOR = 1e4;
    uint256 public minBlockInterval;
    uint256 public maxBlockInterval;

    // Events
    event PriceUpdate(address token, uint256 price, uint256 timestamp, uint256 blockNumber);
    event SignerUpdate(address token, address signer, bool isActive);
    event MinSignersUpdate(address token, uint256 minSigners);

    // Errors
    error InvalidPrice();
    error StalePrice();
    error InvalidSigner();
    error InvalidSignature();
    error InsufficientSigners();
    error PriceDeviationTooLarge();
    error BlockIntervalInvalid(uint256 id, uint256 blockNumber, uint256 previousBlockNumber);

    constructor(
        uint256 _minBlockInterval, 
        uint256 _maxBlockInterval
    ) Ownable(msg.sender) {
        minBlockInterval = _minBlockInterval;
        maxBlockInterval = _maxBlockInterval;
    }

    // View functions
    function getPrice(address token) external view returns (uint256) {
        console.log("getting price for token", token);

        Price memory price = prices[token];
        console.log("price.value", price.value);
        if (price.value == 0) revert InvalidPrice();
        if (block.timestamp - price.timestamp > maxPriceAge[token]) revert StalePrice();
        return price.value;
    }

    // Admin functions
    function setSigner(address token, address signer, bool isActive) external onlyOwner {
        signers[token][signer] = isActive;
        emit SignerUpdate(token, signer, isActive);
    }

    function setMinSigners(address token, uint256 _minSigners) external onlyOwner {
        minSigners[token] = _minSigners;
        emit MinSignersUpdate(token, _minSigners);
    }

    function setMaxPriceAge(address token, uint256 _maxAge) external onlyOwner {
        maxPriceAge[token] = _maxAge;
    }

    // Main price update function
    function setPrices(
        address[] calldata tokens,
        SignedPrice[] calldata signedPrices
    ) external nonReentrant {
        if (tokens.length == 0) revert InvalidPrice();
        if (tokens.length != signedPrices.length) revert InvalidPrice();

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            SignedPrice calldata priceData = signedPrices[i];

            validateBlockInterval(priceData.blockNumber, prices[token].blockNumber);
            validatePrice(token, priceData.price, priceData.timestamp);
            validateSignature(token, priceData);
            
            prices[token] = Price({
                value: priceData.price,
                timestamp: priceData.timestamp,
                blockNumber: priceData.blockNumber,
                minBlockInterval: minBlockInterval,
                maxBlockInterval: maxBlockInterval
            });

            emit PriceUpdate(token, priceData.price, priceData.timestamp, priceData.blockNumber);
        }
    }

    // Validation functions
    function validateBlockInterval(uint256 blockNumber, uint256 previousBlockNumber) internal view {
        if (blockNumber <= previousBlockNumber) revert BlockIntervalInvalid(0, blockNumber, previousBlockNumber);
        
        uint256 blockDiff = blockNumber - previousBlockNumber;
        if (blockDiff < minBlockInterval) revert BlockIntervalInvalid(1, blockDiff, minBlockInterval);
        if (blockDiff > maxBlockInterval) revert BlockIntervalInvalid(2, blockDiff, maxBlockInterval);
        
        if (blockNumber > block.number) revert BlockIntervalInvalid(3, blockNumber, block.number);
    }

    function validatePrice(address token, uint256 newPrice, uint256 timestamp) internal view {
        Price memory currentPrice = prices[token];
        
        // Restore stale price checks
        if (timestamp <= currentPrice.timestamp) revert StalePrice();
        if (block.timestamp - timestamp > maxPriceAge[token]) revert StalePrice();
        
        // Price deviation check
        if (currentPrice.value != 0) {
            uint256 priceDiff;
            if (newPrice > currentPrice.value) {
                priceDiff = ((newPrice - currentPrice.value) * SCALING_FACTOR) / currentPrice.value;
            } else {
                priceDiff = ((currentPrice.value - newPrice) * SCALING_FACTOR) / currentPrice.value;
            }
            
            if (priceDiff > MAX_PRICE_DEVIATION * PRICE_PRECISION) {
                revert PriceDeviationTooLarge();
            }
        }
    }

    function validateSignature(
        address token,
        SignedPrice calldata priceData
    ) internal view {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(
                    token,
                    priceData.price,
                    priceData.timestamp,
                    priceData.blockNumber
                ))
            )
        );

        address signer = messageHash.recover(priceData.signature);
        
        if (!signers[token][signer]) {
            revert InvalidSigner();
        }
    }
}