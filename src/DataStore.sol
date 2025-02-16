// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketFactory.sol";
import "./DepositHandler.sol";
import "./OrderHandler.sol";
contract DataStore {
    mapping(bytes32 => MarketFactory.Market) public markets;
    mapping(address => bytes32) public marketKeys;
    
    mapping(uint256 => DepositHandler.Deposit) public deposits;

    mapping(uint256 => OrderHandler.Order) public orders;

    mapping(TransactionType => uint256) public transactionNonces;

    enum TransactionType {
        Deposit,
        Withdraw,
        Order,
        CloseOrder
    }

    function setMarket(bytes32 key, MarketFactory.Market memory market) external {
        markets[key] = market;
    }

    function setMarketKey(address market, bytes32 key) external {
        marketKeys[market] = key;
    }

    function getMarketKey(address market) external view returns (bytes32) {
        return marketKeys[market];
    }

    function getMarket(bytes32 key) external view returns (MarketFactory.Market memory) {
        return markets[key];
    }

    function setDeposit(uint256 key, DepositHandler.Deposit memory deposit) external {
        deposits[key] = deposit;
    }

    function getDeposit(uint256 key) external view returns (DepositHandler.Deposit memory) {
        return deposits[key];
    }

    function setOrder(uint256 key, OrderHandler.Order memory order) external {
        orders[key] = order;
    }

    function getOrder(uint256 key) external view returns (OrderHandler.Order memory) {
        return orders[key];
    }

    function getNonce(TransactionType _transactionType) external view returns (uint256) {
        return transactionNonces[_transactionType];
    }

    function incrementNonce(TransactionType _transactionType) external {
        transactionNonces[_transactionType]++;
    }
}