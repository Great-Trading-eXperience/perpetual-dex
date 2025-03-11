// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketFactory {
    event MarketCreated(string marketName, address indexed marketToken, address indexed longToken, address indexed shortToken);

    error MarketAlreadyExists(address longToken, address shortToken);

    struct Market {
        address marketToken;
        address longToken;
        address shortToken;
    }

    function dataStore() external view returns (address);
    
    function createMarket(address _longToken, address _shortToken) external returns (address);
}