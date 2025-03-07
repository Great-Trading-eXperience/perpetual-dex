// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OrderVault.sol";
import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketHandler.sol";
import "./Oracle.sol";
import "./PositionHandler.sol";

contract OrderHandler {
    address public dataStore;
    address public orderVault;
    address public wnt;
    address public oracle;
    address public positionHandler;
    address public marketHandler;

    event OrderCreated(uint256 key, Order deposit);
    event OrderCancelled(uint256 key);
    event OrderProcessed(uint256 key);

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

    constructor(address _dataStore, address _orderVault, address _wnt, address _oracle, address _positionHandler, address _marketHandler) {
        dataStore = _dataStore;
        orderVault = _orderVault;
        wnt = _wnt;
        oracle = _oracle;
        positionHandler = _positionHandler;
        marketHandler = _marketHandler;
    }

    function createOrder(
        address _dataStore,
        address _account,
        CreateOrderParams memory _params
    ) external {
        bytes32 marketKey = DataStore(_dataStore).getMarketKey(_params.market);

        if (marketKey == bytes32(0)) {
            revert MarketDoesNotExist();
        }

        MarketFactory.Market memory market = DataStore(_dataStore).getMarket(
            marketKey
        );

        if (market.marketToken != _params.market) {
            revert MarketDoesNotExist();
        }

        if (
            market.longToken != _params.initialCollateralToken &&
            market.shortToken != _params.initialCollateralToken
        ) {
            revert InitialCollateralTokenDoesNotExist();
        }

        uint256 initialCollateralDeltaAmount;
        bool shouldRecordSeparateExecutionFeeTransfer = false;

        if (
            _params.orderType == OrderType.MarketIncrease ||
            _params.orderType == OrderType.LimitIncrease ||
            _params.orderType == OrderType.StopIncrease
        ) {
            initialCollateralDeltaAmount = OrderVault(orderVault)
                .recordTransferIn(_params.initialCollateralToken);

            if (_params.initialCollateralToken == wnt) {
                if (initialCollateralDeltaAmount < _params.executionFee) {
                    revert InsufficientWntAmountForExecutionFee(
                        initialCollateralDeltaAmount,
                        _params.executionFee
                    );
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

        if (order.initialCollateralDeltaAmount > 0) {
            OrderVault(orderVault).transferOut(
                order.initialCollateralToken,
                order.account,
                order.initialCollateralDeltaAmount
            );
        }

        OrderVault(orderVault).transferOut(wnt, order.account, order.executionFee);

        DataStore(_dataStore).setOrder(
            _key,
            Order({
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
            })
        );

        emit OrderCancelled(_key);
    }

    function executeOrder(uint256 _key) external {
        Order memory order = DataStore(dataStore).getOrder(_key);

        uint256 collateralTokenPrice = Oracle(oracle).getPrice(
            order.initialCollateralToken
        );

        if (collateralTokenPrice == 0) {
            revert CollateralTokenPriceIsZero();
        }

        MarketHandler.MarketState memory marketState = MarketHandler(marketHandler).getMarketState(order.marketToken);

        uint256 sizeInTokens = order.sizeDeltaUsd / collateralTokenPrice * (10 ** ERC20(order.initialCollateralToken).decimals());

        if (
            order.orderType == OrderType.MarketIncrease ||
            order.orderType == OrderType.LimitIncrease ||
            order.orderType == OrderType.StopIncrease
        ) {
            if (order.orderType == OrderType.LimitIncrease && order.triggerPrice > collateralTokenPrice) {
                revert TriggerPriceIsGreaterThanCollateralTokenPrice();
            }

            if (collateralTokenPrice > order.acceptablePrice) {
                revert PriceIsGreaterThanAcceptablePrice();
            }

            uint256 availableSizeInTokens = marketState.longTokenAmount - marketState.longTokenOpenInterest;

            if (sizeInTokens > availableSizeInTokens) {
                revert InsufficientTokenAmount();
            }
        } else if (
            order.orderType == OrderType.MarketDecrease ||
            order.orderType == OrderType.LimitDecrease ||
            order.orderType == OrderType.StopLossDecrease
        ) {
            if (order.orderType == OrderType.LimitIncrease && order.triggerPrice > collateralTokenPrice) {
                revert TriggerPriceIsGreaterThanCollateralTokenPrice();
            }
        }

        if (order.validFromTime > block.timestamp) {
            revert OrderIsNotValid();
        }

        _processOrder(_key, order, msg.sender, sizeInTokens);
    }

    function _processOrder(
        uint256 _key,
        Order memory _order,
        address _keeper,
        uint256 _sizeInTokens
    ) internal {
        if (
            _order.orderType == OrderType.MarketIncrease ||
            _order.orderType == OrderType.LimitIncrease
        ) {
            PositionHandler(positionHandler).increasePosition(
                _order,
                _sizeInTokens
            );
            
            OrderVault(orderVault).transferOut(_order.initialCollateralToken, _order.marketToken, _order.initialCollateralDeltaAmount);
        } else if (
            _order.orderType == OrderType.MarketDecrease ||
            _order.orderType == OrderType.LimitDecrease ||
            _order.orderType == OrderType.StopLossDecrease
        ) {
            PositionHandler(positionHandler).decreasePosition(
                _order,
                _sizeInTokens
            );

            MarketToken(_order.marketToken).transferOut(_order.account, _order.initialCollateralToken, _sizeInTokens);
        } else  {
            revert OrderTypeCannotBeExecuted(uint256(_order.orderType));
        } 

        OrderVault(orderVault).transferOut(wnt, _keeper, _order.executionFee);
       
        DataStore(dataStore).setOrder(
            _key,
            Order({
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
            })
        );

        emit OrderProcessed(_key);
    }
}
