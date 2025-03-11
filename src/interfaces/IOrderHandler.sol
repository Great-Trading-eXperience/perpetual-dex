// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOrderHandler {
    enum OrderType {
        MarketIncrease,
        LimitIncrease,
        MarketDecrease,
        LimitDecrease,
        StopLossDecrease,
        StopIncrease,
        Liquidation
    }

    struct CreateOrderParams {
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        OrderType orderType;
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 validFromTime;
        bool isLong;
        bool autoCancel;
    }

    struct Order {
        address account;
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        address marketToken;
        address initialCollateralToken;
        OrderType orderType;
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 updatedAtTime;
        uint256 validFromTime;
        bool isLong;
        bool isFrozen;
    }

    event OrderCreated(
        uint256 key,
        address account,
        address receiver,
        address cancellationReceiver,
        address callbackContract,
        address uiFeeReceiver,
        address marketToken,
        address initialCollateralToken,
        OrderType orderType,
        uint256 sizeDeltaUsd,
        uint256 initialCollateralDeltaAmount,
        uint256 triggerPrice,
        uint256 acceptablePrice,
        uint256 executionFee,
        uint256 updatedAtTime,
        uint256 validFromTime,
        bool isLong,
        bool isFrozen
    );
    
    event OrderCancelled(uint256 key);
    event OrderProcessed(uint256 key);

    // Errors
    error InsufficientExecutionFee();
    error MarketDoesNotExist();
    error OrderTypeCannotBeCreated(uint256 orderType);
    error InitialCollateralTokenDoesNotExist();
    error InsufficientWntAmountForExecutionFee(
        uint256 initialCollateralDeltaAmount,
        uint256 executionFee
    );
    error InsufficientTokenAmount();
    error OnlySelf();
    error CollateralTokenPriceIsZero();
    error TriggerPriceIsGreaterThanCollateralTokenPrice();
    error TriggerPriceIsLessThanCollateralTokenPrice();
    error PriceIsGreaterThanAcceptablePrice();
    error OrderIsNotValid();
    error OrderTypeCannotBeExecuted(uint256 orderType);

    // External functions
    function createOrder(
        address _dataStore,
        address _account,
        CreateOrderParams memory _params
    ) external;

    function cancelOrder(address _dataStore, uint256 _key) external;
    
    function executeOrder(uint256 _key) external;

    // Public state variable getters
    function dataStore() external view returns (address);
    function orderVault() external view returns (address);
    function wnt() external view returns (address);
    function oracle() external view returns (address);
    function positionHandler() external view returns (address);
    function marketHandler() external view returns (address);
}