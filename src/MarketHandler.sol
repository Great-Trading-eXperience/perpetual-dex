// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketToken.sol";
import "./Oracle.sol";

contract MarketHandler {
    address public immutable dataStore;
    address public immutable oracle;

    error MarketDoesNotExist();

    constructor(address _dataStore, address _oracle) {
        dataStore = _dataStore;
        oracle = _oracle;
    }

    struct MarketState {
        uint256 marketTokenSupply;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        address longToken;
        address shortToken;
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

    function getMarketState(address market) internal view returns (MarketState memory) {
        bytes32 marketKey = DataStore(dataStore).getMarketKey(
            market
        );

        if (marketKey == bytes32(0)) {
            revert MarketDoesNotExist();
        }

        MarketFactory.Market memory marketData = DataStore(dataStore).getMarket(marketKey);

        return MarketState({
            marketTokenSupply: MarketToken(marketData.marketToken).totalSupply(),
            longTokenAmount: IERC20(marketData.longToken).balanceOf(marketData.marketToken),
            shortTokenAmount: IERC20(marketData.shortToken).balanceOf(marketData.marketToken),
            longToken: marketData.longToken,
            shortToken: marketData.shortToken
        });
    }
}