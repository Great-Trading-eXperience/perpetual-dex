// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketToken.sol";
import "./Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MarketHandler {
    address public dataStore;
    address public oracle;
    address public positionHandler;

    uint256 public MAX_FUNDING_RATE = 1e15;
    uint256 public MIN_FUNDING_RATE = 1e13; 
    uint256 public BASE_FUNDING_RATE = 1e14;

    uint256 public MAX_OPEN_INTEREST = 8000;
    uint256 public BASE_BORROWING_RATE = 100;
    uint256 public OPTIMAL_UTILIZATION_RATE = 9000;
    uint256 public SLOPE_BELOW_OPTIMAL = 50;
    uint256 public SLOPE_ABOVE_OPTIMAL = 400;

    error MarketDoesNotExist();
    error OnlyPositionHandler();
    error PositionHandlerAlreadySet();
    
    event OpenInterestSet(address market, address token, uint256 amount);
    event FundingFeeSet(address market, int256 amount);
    event GlobalCumulativeFundingFeeSet(address market, int256 amount);

    constructor(address _dataStore, address _oracle) {
        dataStore = _dataStore;
        oracle = _oracle;
    }

    // Only for testing
    function setOracle(address _oracle) external {
        oracle = _oracle;
    }

    function setPositionHandler(address _positionHandler) external {
        if(positionHandler != address(0)) {
            revert PositionHandlerAlreadySet();
        }

        positionHandler = _positionHandler;
    }

    struct MarketState {
        uint256 marketTokenSupply;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        address longToken;
        address shortToken;
        uint256 longTokenOpenInterest;
        uint256 shortTokenOpenInterest;
    }

    function handleDeposit(
        address receiver,
        address market,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) external returns (uint256) {
        uint256 marketTokenAmount = getMarketTokens(
            market,
            longTokenAmount,
            shortTokenAmount
        );

        // Mint market tokens
        MarketToken(market).mint(receiver, marketTokenAmount);

        return marketTokenAmount;
    }

    function getMarketTokens(
        address market,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) public view returns (uint256) {
        MarketState memory state = getMarketState(market);
        uint256 marketTokenSupply = MarketToken(market).totalSupply();

        uint256 longTokenDecimals = IERC20Metadata(state.longToken).decimals(); 
        uint256 shortTokenDecimals = IERC20Metadata(state.shortToken).decimals();

        uint256 longTokenValueInUsd = Oracle(oracle).getPrice(state.longToken) * longTokenAmount / (10 ** longTokenDecimals);
        uint256 shortTokenValueInUsd = Oracle(oracle).getPrice(state.shortToken) * shortTokenAmount / (10 ** shortTokenDecimals);

        uint256 depositValueInUsd = longTokenValueInUsd + shortTokenValueInUsd;

        if (marketTokenSupply == 0) {
            return depositValueInUsd;
        }

        uint256 poolValue = getPoolValueUsd(market);

        return (depositValueInUsd * marketTokenSupply) / poolValue;
    }

    function getPoolValueUsd(address market) public view returns (uint256) {
        MarketState memory state = getMarketState(market);
        
        // Get token prices
        uint256 longTokenPrice = Oracle(oracle).getPrice(state.longToken);
        uint256 shortTokenPrice = Oracle(oracle).getPrice(state.shortToken);

        // Get token decimals   
        uint256 longTokenDecimals = IERC20Metadata(state.longToken).decimals();
        uint256 shortTokenDecimals = IERC20Metadata(state.shortToken).decimals();

        // Calculate USD value of pool's tokens
        uint256 longTokenUsd = (state.longTokenAmount * longTokenPrice) / (10 ** longTokenDecimals);
        uint256 shortTokenUsd = (state.shortTokenAmount * shortTokenPrice) / (10 ** shortTokenDecimals);

        return longTokenUsd + shortTokenUsd;
    }

    function setOpenInterest(address market, address token, uint256 amount) public {
        if (msg.sender != positionHandler) {
            revert OnlyPositionHandler();
        }
        
        DataStore(dataStore).setOpenInterest(market, token, amount);

        emit OpenInterestSet(market, token, amount);
    }

    function getOpenInterest(address _marketToken, address _token) external view returns (uint256) {
        MarketState memory state = getMarketState(_marketToken);
        
        if (_token == state.longToken) {
            return state.longTokenOpenInterest;
        } else {
            return state.shortTokenOpenInterest;
        }
    }

    function setGlobalCumulativeFundingFee(address market, int256 amount) public {
        if (msg.sender != positionHandler) {
            revert OnlyPositionHandler();
        }
        
        DataStore(dataStore).setGlobalCumulativeFundingFee(market, amount);

        emit GlobalCumulativeFundingFeeSet(market, amount);
    }

    function getGlobalCumulativeFundingFee(address market) external view returns (int256) {
        return DataStore(dataStore).getGlobalCumulativeFundingFee(market);
    }

    function setFundingFee(address market, int256 amount) public {
        if (msg.sender != positionHandler) {
            revert OnlyPositionHandler();
        }
        
        DataStore(dataStore).setFundingFee(market, amount);

        emit FundingFeeSet(market, amount);
    }

    function getFundingFee(address market) external view returns (int256) {
        return DataStore(dataStore).getFundingFee(market);
    }

    function getMarketState(address market) public view returns (MarketState memory) {
        bytes32 marketKey = DataStore(dataStore).getMarketKey(
            market
        );

        if (marketKey == bytes32(0)) {
            revert MarketDoesNotExist();
        }

        MarketFactory.Market memory marketData = DataStore(dataStore).getMarket(marketKey);

        uint256 longTokenOpenInterest = DataStore(dataStore).getOpenInterest(market, marketData.longToken);  
        uint256 shortTokenOpenInterest = DataStore(dataStore).getOpenInterest(market, marketData.shortToken);

        return MarketState({
            marketTokenSupply: MarketToken(marketData.marketToken).totalSupply(),
            longTokenAmount: IERC20(marketData.longToken).balanceOf(marketData.marketToken),
            shortTokenAmount: IERC20(marketData.shortToken).balanceOf(marketData.marketToken),
            longToken: marketData.longToken,
            shortToken: marketData.shortToken,
            longTokenOpenInterest: longTokenOpenInterest,
            shortTokenOpenInterest: shortTokenOpenInterest
        });
    }

    function handleWithdraw(
        address receiver,
        address marketToken,
        uint256 marketTokenAmount,
        uint256 longTokenAmount,
        uint256 shortTokenAmount
    ) external {
        MarketState memory state = getMarketState(marketToken);
        
        // Get total pool value in USD (in 1e18)
        uint256 poolValueUsd = getPoolValueUsd(marketToken);
        uint256 marketTokenSupply = MarketToken(marketToken).totalSupply();
        
        // Calculate the proportion of the pool being withdrawn in USD (in 1e18)
        uint256 withdrawValueUsd = (marketTokenAmount * poolValueUsd) / marketTokenSupply;
        
        // Get token prices (in 1e18)
        uint256 longTokenPrice = Oracle(oracle).getPrice(state.longToken);  // 3000 * 1e18
        uint256 shortTokenPrice = Oracle(oracle).getPrice(state.shortToken); // 1 * 1e18
        
        // Calculate proportions (in basis points, 10000 = 100%)
        uint256 totalAmount = longTokenAmount + shortTokenAmount;
        uint256 longTokenProportion = (longTokenAmount * 10000) / totalAmount;
        uint256 shortTokenProportion = (shortTokenAmount * 10000) / totalAmount;
        
        // Calculate USD value for each token based on proportions (in 1e18)
        uint256 longTokenValueUsd = (withdrawValueUsd * longTokenProportion) / 10000;
        uint256 shortTokenValueUsd = (withdrawValueUsd * shortTokenProportion) / 10000;
        
        // Convert USD values back to token amounts
        // For long token (WNT): 
        uint256 longTokenOutput = (longTokenValueUsd * (10 ** IERC20Metadata(state.longToken).decimals())) / longTokenPrice;
        
        // For short token (USDC):
        uint256 shortTokenOutput = (shortTokenValueUsd * (10 ** IERC20Metadata(state.shortToken).decimals())) / shortTokenPrice;
                  
        // Transfer tokens to receiver
        MarketToken(marketToken).syncBalance(state.longToken);
        MarketToken(marketToken).syncBalance(state.shortToken);
        MarketToken(marketToken).transferOut(state.longToken, receiver, longTokenOutput);
        MarketToken(marketToken).transferOut(state.shortToken, receiver, shortTokenOutput);
    }
}