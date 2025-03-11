// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketHandler {
    struct MarketState {
        uint256 marketTokenSupply;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        address longToken;
        address shortToken;
        uint256 longTokenOpenInterest;
        uint256 shortTokenOpenInterest;
    }

    error MarketDoesNotExist();
    error OnlyPositionHandler();
    error PositionHandlerAlreadySet();
    
    event OpenInterestSet(address market, address token, uint256 amount);
    event FundingFeeSet(address market, int256 amount);
    event GlobalCumulativeFundingFeeSet(address market, int256 amount);

    function setPositionHandler(address _positionHandler) external;

    function handleDeposit(
        address receiver,
        address market,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) external returns (uint256);

    function getMarketTokens(
        address market,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) external view returns (uint256);

    function getPoolValueUsd(address market) external view returns (uint256);

    function setOpenInterest(address market, address token, uint256 amount) external;

    function getOpenInterest(address _marketToken, address _token) external view returns (uint256);

    function setGlobalCumulativeFundingFee(address market, int256 amount) external;

    function getGlobalCumulativeFundingFee(address market) external view returns (int256);

    function setFundingFee(address market, int256 amount) external;

    function getFundingFee(address market) external view returns (int256);

    function getMarketState(address market) external view returns (MarketState memory);

    function handleWithdraw(
        address receiver,
        address marketToken,
        uint256 marketTokenAmount,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) external;

    // Public state variables getters
    function dataStore() external view returns (address);
    function oracle() external view returns (address);
    function positionHandler() external view returns (address);
    
    function MAX_FUNDING_RATE() external view returns (uint256);
    function MIN_FUNDING_RATE() external view returns (uint256);
    function BASE_FUNDING_RATE() external view returns (uint256);
    
    function MAX_OPEN_INTEREST() external view returns (uint256);
    function BASE_BORROWING_RATE() external view returns (uint256);
    function OPTIMAL_UTILIZATION_RATE() external view returns (uint256);
    function SLOPE_BELOW_OPTIMAL() external view returns (uint256);
    function SLOPE_ABOVE_OPTIMAL() external view returns (uint256);
}