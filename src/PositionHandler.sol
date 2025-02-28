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
        int256 latestCumulativeFundingFee,
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
        int256 latestCumulativeFundingFee,
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
        int256 latestCumulativeFundingFee;
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
        
        int256 latestCumulativeFundingFee = MarketHandler(marketHandler).getGlobalCumulativeFundingFee(_order.marketToken);
    
        Position memory position = DataStore(dataStore).getPosition(positionKey);

        MarketHandler.MarketState memory marketState = MarketHandler(marketHandler).getMarketState(_order.marketToken);

        bool isLong = _order.initialCollateralToken == marketState.longToken;

        int256 globalCumulativeFundingFee = MarketHandler(marketHandler).getGlobalCumulativeFundingFee(_order.marketToken);
        uint256 longOpenInterest = MarketHandler(marketHandler).getOpenInterest(_order.marketToken, marketState.longToken);
        uint256 shortOpenInterest = MarketHandler(marketHandler).getOpenInterest(_order.marketToken, marketState.shortToken);
        int256 imbalance = int256(longOpenInterest) - int256(shortOpenInterest);
        uint256 totalOI = longOpenInterest + shortOpenInterest;
        int256 priceImpactFactor;

        if (totalOI > 0) {
            priceImpactFactor = (imbalance * 1e18) / int256(totalOI);
        }

        // Base funding rate starts at 0.01% (1e14) per hour
        uint256 baseFundingRate = 1e14;
        
        // Increase funding rate based on price impact
        int256 adjustedFundingRate;
        if (priceImpactFactor >= 0) {
            adjustedFundingRate = int256(baseFundingRate) + ((int256(baseFundingRate) * priceImpactFactor) / 1e18);
        } else {
            adjustedFundingRate = int256(baseFundingRate) - ((int256(baseFundingRate) * (-priceImpactFactor)) / 1e18);
        }

        int256 fundingFeeRate;
        if (imbalance > 0) {
            fundingFeeRate = isLong ? adjustedFundingRate : -adjustedFundingRate;
        } else {
            fundingFeeRate = !isLong ? adjustedFundingRate : -adjustedFundingRate;
        }

        uint256 hoursElapsed = (block.timestamp - position.increasedAtTime) / 3600;
        int256 periodFundingFee = (int256(position.sizeInTokens) * fundingFeeRate * int256(hoursElapsed)) / 1e18;
        
        int256 fundingFee = periodFundingFee;
        
        if (globalCumulativeFundingFee != position.latestCumulativeFundingFee) {
            int256 cumulativeFundingDiff = int256(globalCumulativeFundingFee) - int256(position.latestCumulativeFundingFee);
            int256 globalFundingFee = (int256(position.sizeInTokens) * cumulativeFundingDiff) / 1e18;
            fundingFee += globalFundingFee;
        }
        
        position.latestCumulativeFundingFee = globalCumulativeFundingFee;
        
        uint256 absoluteFundingFee = fundingFee >= 0 ? uint256(fundingFee) : uint256(-fundingFee);
        bool isFundingFeePositive = fundingFee >= 0;
        
        position.account = _order.account;
        position.market = _order.marketToken;
        position.collateralToken = _order.initialCollateralToken;
        position.sizeInUsd += _order.sizeDeltaUsd;
        position.sizeInTokens += _sizeInTokens;
        position.collateralAmount += _order.initialCollateralDeltaAmount;
        position.increasedAtTime = block.timestamp;
        position.isLong = _order.isLong;

        if (isLong) {
            MarketHandler(marketHandler).setOpenInterest(_order.marketToken, _order.initialCollateralToken, longOpenInterest + position.sizeInTokens);
        } else {
            MarketHandler(marketHandler).setOpenInterest(_order.marketToken, _order.initialCollateralToken, shortOpenInterest + position.sizeInTokens);
        }

        MarketHandler(marketHandler).setGlobalCumulativeFundingFee(_order.marketToken, fundingFee);

        DataStore(dataStore).setPosition(positionKey, position);
    
        emit PositionIncreased(
            positionKey,
            position.isLong,
            position.sizeInUsd,
            position.sizeInTokens,
            position.collateralAmount,
            position.borrowingFactor,
            position.latestCumulativeFundingFee,
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
            position.latestCumulativeFundingFee,
            position.increasedAtTime,
            position.decreasedAtTime,
            position.collateralToken,
            position.account,
            position.market
        );
    }
}
