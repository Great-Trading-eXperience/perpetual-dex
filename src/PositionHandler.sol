// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "./MarketHandler.sol";
import "./OrderHandler.sol";
import "./DataStore.sol";

contract PositionHandler {
    address public dataStore;
    address public oracle;
    address public orderHandler;
    address public marketHandler;

    uint256 public MAINTENCANCE_MARGIN_FACTOR = 1000;
    uint256 public LIQUIDATION_FEE = 500;
    uint256 public POSITION_FEE = 10;
    uint256 public MAX_LEVERAGE = 20;

    error OnlyOrderHandler();
    error InsufficientPositionSize();
    error OrderHandlerAlreadySet();
    error LeverageExceeded(uint256 leverage);
    error PositionLiquidatable(bytes32 positionKey);
    error PositionNotLiquidatable(bytes32 positionKey);
    error OpenInterestExceeded(uint256 openInterest, uint256 maxOpenInterest);

    event PositionIncreased(
        bytes32 positionKey,
        bool isLong,
        uint256 sizeInUsd,
        uint256 sizeInTokens,
        uint256 collateralAmount,
        uint256 cumulativeBorrowingFee,
        int256 cumulativeFundingFee,
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
        uint256 cumulativeBorrowingFee,
        int256 cumulativeFundingFee,
        uint256 increasedAtTime,
        uint256 decreasedAtTime,
        address collateralToken,
        address account,
        address market
    );

    event PositionLiquidated(
        bytes32 positionKey,
        address account,
        address market,
        address collateralToken,
        uint256 collateralAmount,
        uint256 cumulativeBorrowingFee,
        int256 cumulativeFundingFee,
        uint256 increasedAtTime,
        uint256 decreasedAtTime,
        uint256 liquidationFee,
        uint256 liquidationPrice,
        address liquidator
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
        int256 cumulativeFundingFee;
        uint256 cumulativeBorrowingFee;
        uint256 increasedAtTime;
        uint256 decreasedAtTime;
        // Flag fields
        bool isLong;
    }

    struct LiquidatePositionParams {
        address account;
        address market;
        address collateralToken;
    }

    constructor(address _dataStore, address _oracle, address _marketHandler) {
        dataStore = _dataStore;
        oracle = _oracle;
        marketHandler = _marketHandler;
    }

    function setOrderHandler(address _orderHandler) external {
        if (orderHandler != address(0)) {
            revert OrderHandlerAlreadySet();
        }

        orderHandler = _orderHandler;
    }

    function updateFees(
        Position memory position,
        uint256 collateralAmount,
        OrderHandler.OrderType orderType
    ) internal returns (Position memory updatedPosition) {
        MarketHandler.MarketState memory marketState = MarketHandler(
            marketHandler
        ).getMarketState(position.market);

        // 1. Calculate funding fee
        int256 globalCumulativeFundingFee = MarketHandler(marketHandler)
            .getGlobalCumulativeFundingFee(position.market);
        uint256 longOpenInterest = MarketHandler(marketHandler).getOpenInterest(
            position.market,
            marketState.longToken
        );
        uint256 shortOpenInterest = MarketHandler(marketHandler)
            .getOpenInterest(position.market, marketState.shortToken);

        if (
            orderType == OrderHandler.OrderType.MarketIncrease ||
            orderType == OrderHandler.OrderType.LimitIncrease ||
            orderType == OrderHandler.OrderType.StopIncrease
        ) {
            if (position.isLong) {
                longOpenInterest += position.sizeInTokens;
            } else {
                shortOpenInterest += position.sizeInTokens;
            }
        } else if (
            orderType == OrderHandler.OrderType.MarketDecrease ||
            orderType == OrderHandler.OrderType.LimitDecrease ||
            orderType == OrderHandler.OrderType.StopLossDecrease
        ) {
            if (position.isLong) {
                longOpenInterest -= position.sizeInTokens;
            } else {
                shortOpenInterest -= position.sizeInTokens;
            }
        } else if (orderType == OrderHandler.OrderType.Liquidation) {
            if (position.isLong) {
                longOpenInterest -= position.sizeInTokens;
            } else {
                shortOpenInterest -= position.sizeInTokens;
            }
        }

        if (position.isLong) {
            uint256 maxOpenInterest = MarketHandler(marketHandler)
                .MAX_OPEN_INTEREST() * marketState.longTokenAmount;
            if (longOpenInterest > maxOpenInterest) {
                revert OpenInterestExceeded(longOpenInterest, maxOpenInterest);
            }
        } else {
            uint256 maxOpenInterest = MarketHandler(marketHandler)
                .MAX_OPEN_INTEREST() * marketState.shortTokenAmount;
            if (shortOpenInterest > maxOpenInterest) {
                revert OpenInterestExceeded(shortOpenInterest, maxOpenInterest);
            }
        }

        int256 imbalance = int256(longOpenInterest) - int256(shortOpenInterest);
        uint256 totalOI = longOpenInterest + shortOpenInterest;
        int256 priceImpactFactor;

        if (totalOI > 0) {
            priceImpactFactor = (imbalance * 1e18) / int256(totalOI);
        }

        int256 adjustedFundingRate = int256(
            MarketHandler(marketHandler).BASE_FUNDING_RATE()
        );
        if (priceImpactFactor >= 0) {
            adjustedFundingRate =
                int256(adjustedFundingRate) +
                ((int256(adjustedFundingRate) * priceImpactFactor) / 1e18);
        } else {
            adjustedFundingRate =
                int256(adjustedFundingRate) -
                ((int256(adjustedFundingRate) * (-priceImpactFactor)) / 1e18);
        }

        if (
            adjustedFundingRate >
            int256(MarketHandler(marketHandler).MAX_FUNDING_RATE())
        ) {
            adjustedFundingRate = int256(
                MarketHandler(marketHandler).MAX_FUNDING_RATE()
            );
        } else if (
            adjustedFundingRate <
            int256(MarketHandler(marketHandler).MIN_FUNDING_RATE())
        ) {
            adjustedFundingRate = int256(
                MarketHandler(marketHandler).MIN_FUNDING_RATE()
            );
        }

        int256 fundingFee;
        if (imbalance > 0) {
            fundingFee = position.isLong
                ? adjustedFundingRate
                : -adjustedFundingRate;
        } else {
            fundingFee = !position.isLong
                ? adjustedFundingRate
                : -adjustedFundingRate;
        }

        uint256 hoursElapsed = (block.timestamp - position.increasedAtTime) /
            3600;
        uint256 tokenDecimals = IERC20Metadata(position.collateralToken).decimals();
        int256 periodFundingFee = (int256(position.sizeInTokens) *
            fundingFee *
            int256(hoursElapsed)) / int256(10 ** tokenDecimals);

        // 2. Calculate borrowing fee
        uint256 currentUtilizationRate = position.isLong
            ? (longOpenInterest * 100) / marketState.longTokenAmount
            : shortOpenInterest / marketState.shortTokenAmount;
        uint256 utilizationAdjustment;

        if (
            currentUtilizationRate <=
            MarketHandler(marketHandler).OPTIMAL_UTILIZATION_RATE()
        ) {
            utilizationAdjustment =
                (currentUtilizationRate *
                    MarketHandler(marketHandler).SLOPE_BELOW_OPTIMAL() *
                    100) /
                MarketHandler(marketHandler).OPTIMAL_UTILIZATION_RATE();
        } else {
            utilizationAdjustment =
                MarketHandler(marketHandler).SLOPE_BELOW_OPTIMAL() +
                (((currentUtilizationRate -
                    MarketHandler(marketHandler).OPTIMAL_UTILIZATION_RATE()) *
                    MarketHandler(marketHandler).SLOPE_ABOVE_OPTIMAL()) /
                    (100 -
                        MarketHandler(marketHandler)
                            .OPTIMAL_UTILIZATION_RATE()));
        }

        uint256 totalBorrowingRate = MarketHandler(marketHandler)
            .BASE_BORROWING_RATE() + utilizationAdjustment;
        uint256 periodBorrowingFee = (position.sizeInTokens *
            totalBorrowingRate *
            hoursElapsed) /
            8760 /
            10000;

        // 3. Calculate position fee
        uint256 positionFee = (position.sizeInTokens * POSITION_FEE) / 10000;

        // Update position
        position.cumulativeFundingFee += periodFundingFee;
        position.cumulativeBorrowingFee += periodBorrowingFee;

        if (periodFundingFee > 0) {
            position.collateralAmount -= uint256(periodFundingFee);
        } else {
            position.collateralAmount += uint256(-periodFundingFee);
        }

        position.collateralAmount -= (periodBorrowingFee + positionFee);

        MarketToken(position.market).syncBalance(position.collateralToken);
        MarketToken(position.market).transferOut(
            position.isLong ? marketState.longToken : marketState.shortToken,
            position.market,
            periodBorrowingFee + positionFee
        );

        if (position.isLong) {
            MarketHandler(marketHandler).setOpenInterest(
                position.market,
                position.collateralToken,
                longOpenInterest
            );
        } else {
            MarketHandler(marketHandler).setOpenInterest(
                position.market,
                position.collateralToken,
                shortOpenInterest
            );
        }

        MarketHandler(marketHandler).setGlobalCumulativeFundingFee(
            position.market,
            globalCumulativeFundingFee
        );
        MarketHandler(marketHandler).setFundingFee(
            position.market,
            adjustedFundingRate
        );

        return position;
    }

    function getPnl(Position memory position) internal view returns (int256) {
        uint256 currentPrice = Oracle(oracle).getPrice(
            position.collateralToken
        );
        uint256 entryPrice = position.sizeInUsd / position.sizeInTokens;

        int256 priceDifference = int256(currentPrice) - int256(entryPrice);

        return
            (priceDifference * int256(position.collateralAmount)) /
            int256(10 ** ERC20(position.collateralToken).decimals());
    }

    function isPosisitionLiquidatable(
        Position memory position
    ) internal view returns (bool) {
        uint256 maintenanceMarginFactor = (position.sizeInUsd *
            MAINTENCANCE_MARGIN_FACTOR) / 10000;
        int256 pnl = getPnl(position);
        return pnl <= int256(maintenanceMarginFactor);
    }

    function increasePosition(
        OrderHandler.Order memory _order,
        uint256 _sizeInTokens
    ) external {
        if (msg.sender != orderHandler) {
            revert OnlyOrderHandler();
        }

        bytes32 positionKey = keccak256(
            abi.encodePacked(
                _order.account,
                _order.marketToken,
                _order.initialCollateralToken
            )
        );
        Position memory position = DataStore(dataStore).getPosition(
            positionKey
        );

        position.account = _order.account;
        position.market = _order.marketToken;
        position.collateralToken = _order.initialCollateralToken;
        position.sizeInUsd += _order.sizeDeltaUsd;
        position.sizeInTokens += _sizeInTokens;
        position.collateralAmount += _order.initialCollateralDeltaAmount;
        position.increasedAtTime = block.timestamp;
        position.isLong = _order.isLong;

        if (
            (position.sizeInTokens * 10) / position.collateralAmount >
            MAX_LEVERAGE * 10
        ) {
            revert LeverageExceeded(
                position.sizeInTokens / position.collateralAmount
            );
        }

        position = updateFees(
            position,
            _order.initialCollateralDeltaAmount,
            _order.orderType
        );

        DataStore(dataStore).setPosition(positionKey, position);

        emit PositionIncreased(
            positionKey,
            position.isLong,
            position.sizeInUsd,
            position.sizeInTokens,
            position.collateralAmount,
            position.cumulativeBorrowingFee,
            position.cumulativeFundingFee,
            position.increasedAtTime,
            position.decreasedAtTime,
            position.collateralToken,
            position.account,
            position.market
        );
    }

    function decreasePosition(
        OrderHandler.Order memory _order,
        uint256 _sizeInTokens
    ) external {
        if (msg.sender != orderHandler) {
            revert OnlyOrderHandler();
        }

        bytes32 positionKey = keccak256(
            abi.encodePacked(
                _order.account,
                _order.marketToken,
                _order.initialCollateralToken
            )
        );

        Position memory position = DataStore(dataStore).getPosition(
            positionKey
        );

        if (
            position.sizeInTokens < _sizeInTokens ||
            position.sizeInUsd < _order.sizeDeltaUsd ||
            position.collateralAmount < _order.initialCollateralDeltaAmount
        ) {
            revert InsufficientPositionSize();
        }

        if (isPosisitionLiquidatable(position)) {
            revert PositionLiquidatable(positionKey);
        }

        int256 pnl = getPnl(position);
        uint256 retrievedPnl = (uint256(pnl) * _sizeInTokens) /
            position.sizeInTokens;

        if (retrievedPnl > 0) {
            MarketToken(position.market).transferOut(
                position.collateralToken,
                position.account,
                retrievedPnl
            );
        }

        position.sizeInUsd -= _order.sizeDeltaUsd;
        position.sizeInTokens -= _sizeInTokens;
        position.collateralAmount -= _order.initialCollateralDeltaAmount;
        position.decreasedAtTime = block.timestamp;

        position = updateFees(
            position,
            _order.initialCollateralDeltaAmount,
            OrderHandler.OrderType.MarketDecrease
        );

        DataStore(dataStore).setPosition(positionKey, position);

        emit PositionDecreased(
            positionKey,
            position.isLong,
            position.sizeInUsd,
            position.sizeInTokens,
            position.collateralAmount,
            position.cumulativeBorrowingFee,
            position.cumulativeFundingFee,
            position.increasedAtTime,
            position.decreasedAtTime,
            position.collateralToken,
            position.account,
            position.market
        );
    }

    function liquidatePosition(
        LiquidatePositionParams memory _params,
        address _liquidator
    ) external {
        bytes32 positionKey = keccak256(
            abi.encodePacked(
                _params.account,
                _params.market,
                _params.collateralToken
            )
        );
        Position memory position = DataStore(dataStore).getPosition(
            positionKey
        );

        if (!isPosisitionLiquidatable(position)) {
            revert PositionNotLiquidatable(positionKey);
        }

        position = updateFees(position, 0, OrderHandler.OrderType.Liquidation);

        uint256 liquidationFee = (position.collateralAmount * LIQUIDATION_FEE) /
            10000;
        position.collateralAmount -= liquidationFee;
        Position memory liquidatedPosition = position;

        uint256 collateralAmount = position.collateralAmount;

        position.sizeInUsd = 0;
        position.sizeInTokens = 0;
        position.collateralAmount = 0;
        position.decreasedAtTime = block.timestamp;

        MarketToken(_params.market).transferOut(
            _params.collateralToken,
            _liquidator,
            liquidationFee
        );

        DataStore(dataStore).setPosition(positionKey, position);

        uint256 currentPrice = Oracle(oracle).getPrice(
            position.collateralToken
        );

        emit PositionLiquidated(
            positionKey,
            liquidatedPosition.account,
            liquidatedPosition.market,
            liquidatedPosition.collateralToken,
            collateralAmount,
            liquidatedPosition.cumulativeBorrowingFee,
            liquidatedPosition.cumulativeFundingFee,
            liquidatedPosition.increasedAtTime,
            liquidatedPosition.decreasedAtTime,
            liquidationFee,
            currentPrice,
            _liquidator
        );
    }
}
