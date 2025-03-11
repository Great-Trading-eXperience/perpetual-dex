// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IOrderHandler.sol";
import "./IDataStore.sol";
import "./IMarketHandler.sol";

interface IPositionHandler {
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

    function setOrderHandler(address _orderHandler) external;
    
    function increasePosition(
        IOrderHandler.Order memory _order,
        uint256 _sizeInTokens
    ) external;
    
    function decreasePosition(
        IOrderHandler.Order memory _order,
        uint256 _sizeInTokens
    ) external;
    
    function liquidatePosition(
        IPositionHandler.LiquidatePositionParams memory _params,
        address _liquidator
    ) external;
    
    // Public state variables getters
    function dataStore() external view returns (address);
    function oracle() external view returns (address);
    function orderHandler() external view returns (address);
    function marketHandler() external view returns (address);
    function MAINTENCANCE_MARGIN_FACTOR() external view returns (uint256);
    function LIQUIDATION_FEE() external view returns (uint256);
    function POSITION_FEE() external view returns (uint256);
    function MAX_LEVERAGE() external view returns (uint256);
}