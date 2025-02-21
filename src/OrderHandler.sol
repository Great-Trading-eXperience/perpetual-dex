// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OrderVault.sol";
import "./DataStore.sol";
import "./MarketFactory.sol";

contract OrderHandler {
    address public orderVault;
    address public wnt;

    event OrderCreated(uint256 key, Order deposit);
    event OrderCancelled(uint256 key);

    error InsufficientExecutionFee();
    error MarketDoesNotExist();
    error OrderTypeCannotBeCreated(uint256 orderType);
    error InitialCollateralTokenDoesNotExist();
    error InsufficientWntAmountForExecutionFee(uint256 initialCollateralDeltaAmount, uint256 executionFee);
    error OnlySelf();

    enum OrderType {
        MarketIncrease,
        LimitIncrease,
        MarketDecrease,
        LimitDecrease,
        StopLossDecrease,
        Liquidation,
        StopIncrease
    }

    struct CreateOrderParams {
        // Address parameters
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address initialCollateralToken;
        // address[] swapPath;

        // Order type parameters
        OrderType orderType;
        // DecreasePositionSwapType decreasePositionSwapType;

        // Numerical parameters
        uint256 sizeDeltaUsd;
        uint256 initialCollateralDeltaAmount;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        // uint256 callbackGasLimit;
        // uint256 minOutputAmount;
        uint256 validFromTime;
        // Boolean parameters
        bool isLong;
        // bool shouldUnwrapNativeToken;
        bool autoCancel;

        // Additional parameters
        // bytes32 referralCode;
    }

    struct Order {
        // Account related addresses
        address account;
        address receiver;
        address cancellationReceiver;
        address callbackContract;
        address uiFeeReceiver;
        // Market related addresses
        address marketToken; // Trading market address
        address initialCollateralToken; // Initial collateral token
        // address[] swapPath;           // Path for token swaps

        // Order type and swap configuration
        OrderType orderType;
        // DecreasePositionSwapType decreasePositionSwapType;

        // Position and collateral parameters
        uint256 sizeDeltaUsd; // Position size change in USD
        uint256 initialCollateralDeltaAmount; // Initial collateral amount
        // Price parameters
        uint256 triggerPrice; // Price to trigger the order
        uint256 acceptablePrice; // Acceptable execution price
        // Fee and gas parameters
        uint256 executionFee; // Fee for keepers
        // uint256 callbackGasLimit;    // Gas limit for callbacks
        // uint256 minOutputAmount;     // Minimum output amount

        // Time parameters
        uint256 updatedAtTime; // Last update timestamp
        uint256 validFromTime; // Time from which order is valid
        // Boolean flags
        bool isLong; // Long or short position
        // bool shouldUnwrapNativeToken; // Whether to unwrap native token
        bool isFrozen; // Whether order is frozen
        // bool autoCancel;             // Whether to auto cancel
    }

    constructor(address _orderVault, address _wnt) {
        orderVault = _orderVault;
        wnt = _wnt;
    }

    function createOrder(
        address _dataStore,
        address _account,
        CreateOrderParams memory _params
    ) external {
        bytes32 marketKey = DataStore(_dataStore).getMarketKey(
            _params.market
        );

        if (marketKey == bytes32(0)) {
            revert MarketDoesNotExist();
        }

        MarketFactory.Market memory market = DataStore(_dataStore).getMarket(marketKey);

        if (market.marketToken != _params.market) {
            revert MarketDoesNotExist();
        }

        if(market.longToken != _params.initialCollateralToken && market.shortToken != _params.initialCollateralToken) {
            revert InitialCollateralTokenDoesNotExist();
        }

        uint256 initialCollateralDeltaAmount;
        bool shouldRecordSeparateExecutionFeeTransfer = false;

        if (
            _params.orderType == OrderType.MarketIncrease ||
            _params.orderType == OrderType.LimitIncrease ||
            _params.orderType == OrderType.StopIncrease
        ) {
            initialCollateralDeltaAmount = OrderVault(orderVault).recordTransferIn(_params.initialCollateralToken);
           
            if (_params.initialCollateralToken == wnt) {
                if (initialCollateralDeltaAmount < _params.executionFee) {
                    revert InsufficientWntAmountForExecutionFee(initialCollateralDeltaAmount, _params.executionFee);
                }
                initialCollateralDeltaAmount -= _params.executionFee;
                shouldRecordSeparateExecutionFeeTransfer = false;
            }
        } else if (
            _params.orderType == OrderType.MarketDecrease ||
            _params.orderType == OrderType.LimitDecrease ||
            _params.orderType == OrderType.StopLossDecrease
        ) {
            initialCollateralDeltaAmount = _params.initialCollateralDeltaAmount;
        } else {
            revert OrderTypeCannotBeCreated(uint256(_params.orderType));
        }

        uint256 executionFeeAmount;

        if (shouldRecordSeparateExecutionFeeTransfer) {
            executionFeeAmount = OrderVault(orderVault).recordTransferIn(wnt);

            if (executionFeeAmount < _params.executionFee) {
                revert InsufficientExecutionFee();
            }
        } else {
            executionFeeAmount = _params.executionFee;
        }

        if (executionFeeAmount < _params.executionFee) {
            revert InsufficientExecutionFee();
        }

        uint256 nonce = DataStore(_dataStore).getNonce(
            DataStore.TransactionType.Order
        );

        Order memory depositData = Order(
            _account,
            _params.receiver,
            _params.cancellationReceiver,
            _params.callbackContract,
            _params.uiFeeReceiver,
            _params.market,
            _params.initialCollateralToken,
            _params.orderType,
            _params.sizeDeltaUsd,
            initialCollateralDeltaAmount,
            _params.triggerPrice,
            _params.acceptablePrice,
            _params.executionFee,
            block.timestamp,
            _params.validFromTime,
            _params.isLong,
            false
        );

        DataStore(_dataStore).setOrder(nonce, depositData);

        DataStore(_dataStore).incrementNonce(DataStore.TransactionType.Order);

        emit OrderCreated(nonce, depositData);
    }

    function cancelOrder(address _dataStore, uint256 _key) external {
        Order memory order = DataStore(_dataStore).getOrder(_key);

        if(order.initialCollateralDeltaAmount > 0) {
            OrderVault(orderVault).transferOut(order.initialCollateralToken, order.initialCollateralDeltaAmount);
        }

        OrderVault(orderVault).transferOut(wnt, order.executionFee);

        DataStore(_dataStore).setOrder(_key, Order({
            account: address(0),
            receiver: address(0),
            cancellationReceiver: address(0),
            callbackContract: address(0),
            uiFeeReceiver: address(0),
            marketToken: address(0),
            initialCollateralToken: address(0),
            orderType: OrderType.StopIncrease,
            sizeDeltaUsd: 0,
            initialCollateralDeltaAmount: 0,
            triggerPrice: 0,
            acceptablePrice: 0,
            executionFee: 0,
            updatedAtTime: 0,
            validFromTime: 0,
            isLong: false,
            isFrozen: false
        }));

        emit OrderCancelled(_key);
    }

    function executeOrder(address _dataStore, uint256 _key) external {
        uint256 startingGas = gasleft();

        Order memory order = DataStore(_dataStore).getOrder(_key);
       
        // Gas validation
       
        // Order execution
    }

    function _executeOrder(uint256 _key, Order memory _order, address _keeper) external {
        if(msg.sender != address(this)) {
            revert OnlySelf();
        }

        // Non empty order validation
        // BaseOrderUtils.validateNonEmptyOrder(params.order);
        
        // Trigger price validation
        // BaseOrderUtils.validateOrderTriggerPrice(
        //     params.contracts.oracle,
        //     params.market.indexToken,
        //     params.order.orderType(),
        //     params.order.triggerPrice(),
        //     params.order.isLong()
        // );

        // Valid from time validation
        // BaseOrderUtils.validateOrderValidFromTime(
        //     params.order.orderType(),
        //     params.order.validFromTime()
        // );
    }
}
