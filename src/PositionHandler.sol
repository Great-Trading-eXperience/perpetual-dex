// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketHandler.sol";   
import "./OrderHandler.sol";
import "./DataStore.sol";

contract PositionHandler {
    address public dataStore;
    address public orderHandler;
    address public marketHandler;

    error OnlyOrderHandler();
    error InsufficientPositionSize();
    error OrderHandlerAlreadySet();

    event PositionIncreased(
        bytes32 positionKey,
        bool isLong,
        uint256 sizeInUsd,
        uint256 sizeInTokens,
        uint256 collateralAmount,
        uint256 borrowingFactor,
        uint256 fundingFeeAmountPerSize,
        uint256 longTokenClaimableFundingAmountPerSize,
        uint256 shortTokenClaimableFundingAmountPerSize,
        uint256 increasedAtTime,
        uint256 decreasedAtTime,
        address collateralToken,
        address account,
        address market
    );

    event PositionDecreased(
        bytes32 positionKey,
        bool isLong,
        uint256 sizeInUsd,
        uint256 sizeInTokens,
        uint256 collateralAmount,
        uint256 borrowingFactor,
        uint256 fundingFeeAmountPerSize,
        uint256 longTokenClaimableFundingAmountPerSize,
        uint256 shortTokenClaimableFundingAmountPerSize,
        uint256 increasedAtTime,
        uint256 decreasedAtTime,
        address collateralToken,
        address account,
        address market
    );

    struct Position {
        // Address-related fields
        address account;
        address market;
        address collateralToken;
        
        // Number-related fields
        uint256 sizeInUsd;
        uint256 sizeInTokens;
        uint256 collateralAmount;
        uint256 borrowingFactor;
        uint256 fundingFeeAmountPerSize;
        uint256 longTokenClaimableFundingAmountPerSize;
        uint256 shortTokenClaimableFundingAmountPerSize;
        uint256 increasedAtTime;
        uint256 decreasedAtTime;
        
        // Flag fields
        bool isLong;
    }    

    constructor(address _dataStore, address _marketHandler) {
        dataStore = _dataStore;
        marketHandler = _marketHandler;
    }

    function setOrderHandler(address _orderHandler) external {
        if(orderHandler != address(0)) {
            revert OrderHandlerAlreadySet();
        }

        orderHandler = _orderHandler;
    }

    function increasePosition(OrderHandler.Order memory _order, uint256 _sizeInTokens) external {
        if(msg.sender != orderHandler) {
            revert OnlyOrderHandler();
        }

        bytes32 positionKey = keccak256(abi.encodePacked(_order.account, _order.marketToken, _order.initialCollateralToken, _order.isLong));
        
        Position memory position = DataStore(dataStore).getPosition(positionKey);
    
        position.account = _order.account;
        position.market = _order.marketToken;
        position.collateralToken = _order.initialCollateralToken;
        position.sizeInUsd += _order.sizeDeltaUsd;
        position.sizeInTokens += _sizeInTokens;
        position.collateralAmount += _order.initialCollateralDeltaAmount;
        position.increasedAtTime = block.timestamp;
        position.isLong = _order.isLong;

        uint256 openInterest = MarketHandler(marketHandler).getOpenInterest(_order.marketToken, _order.initialCollateralToken);
        MarketHandler(marketHandler).setOpenInterest(_order.marketToken, _order.initialCollateralToken, openInterest + position.sizeInTokens);

        DataStore(dataStore).setPosition(positionKey, position);
    
        emit PositionIncreased(
            positionKey,
            position.isLong,
            position.sizeInUsd,
            position.sizeInTokens,
            position.collateralAmount,
            position.borrowingFactor,
            position.fundingFeeAmountPerSize,
            position.longTokenClaimableFundingAmountPerSize,
            position.shortTokenClaimableFundingAmountPerSize,
            position.increasedAtTime,
            position.decreasedAtTime,
            position.collateralToken,
            position.account,
            position.market
        );
    }

    function decreasePosition(OrderHandler.Order memory _order, uint256 _sizeInTokens) external {
        if(msg.sender != orderHandler) {
            revert OnlyOrderHandler();
        }

        bytes32 positionKey = keccak256(abi.encodePacked(_order.account, _order.marketToken, _order.initialCollateralToken, _order.isLong));

        Position memory position = DataStore(dataStore).getPosition(positionKey);

        if (position.sizeInTokens < _sizeInTokens) {
            revert InsufficientPositionSize();
        }

        position.sizeInUsd -= _order.sizeDeltaUsd;
        position.sizeInTokens -= _sizeInTokens;
        position.decreasedAtTime = block.timestamp;

        uint256 openInterest = MarketHandler(marketHandler).getOpenInterest(_order.marketToken, _order.initialCollateralToken);
        MarketHandler(marketHandler).setOpenInterest(_order.marketToken, _order.initialCollateralToken, openInterest - position.sizeInTokens);

        DataStore(dataStore).setPosition(positionKey, position);

        emit PositionDecreased(
            positionKey,
            position.isLong,
            position.sizeInUsd,
            position.sizeInTokens,
            position.collateralAmount,
            position.borrowingFactor,
            position.fundingFeeAmountPerSize,
            position.longTokenClaimableFundingAmountPerSize,
            position.shortTokenClaimableFundingAmountPerSize,
            position.increasedAtTime,
            position.decreasedAtTime,
            position.collateralToken,
            position.account,
            position.market
        );
    }
}
