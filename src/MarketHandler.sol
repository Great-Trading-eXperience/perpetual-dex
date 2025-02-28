// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketToken.sol";
import "./Oracle.sol";

contract MarketHandler {
    address public immutable dataStore;
    address public immutable oracle;
    address public positionHandler;

    error MarketDoesNotExist();
    error OnlyPositionHandler();
    error PositionHandlerAlreadySet();
    
    event OpenInterestSet(address market, address token, uint256 amount);
    event CumulativeFundingFeeSet(address market, uint256 amount);
    event FundingFeeSet(address market, int256 amount);
    event GlobalCumulativeFundingFeeSet(address market, int256 amount);

    constructor(address _dataStore, address _oracle) {
        dataStore = _dataStore;
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
        uint256 depositValueInUsd = (longTokenAmount * Oracle(oracle).getPrice(state.longToken)) + (shortTokenAmount * Oracle(oracle).getPrice(state.shortToken));
        
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

        // Calculate USD value of pool's tokens
        uint256 longTokenUsd = (state.longTokenAmount * longTokenPrice) / 1e18;
        uint256 shortTokenUsd = (state.shortTokenAmount * shortTokenPrice) / 1e18;

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
}