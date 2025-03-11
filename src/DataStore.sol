// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketFactory.sol";
import "./DepositHandler.sol";
import "./OrderHandler.sol";
import "./PositionHandler.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WithdrawHandler.sol";

contract DataStore is Ownable {
    mapping(bytes32 => MarketFactory.Market) public markets;
    mapping(address => bytes32) public marketKeys;
    mapping(address => int256) public cumulativeFundingFee;
    mapping(address => int256) public fundingFee;
    mapping(address => mapping(address => uint256)) public openInterest;
    
    mapping(uint256 => DepositHandler.Deposit) public deposits;

    mapping(uint256 => OrderHandler.Order) public orders;

    mapping(bytes32 => PositionHandler.Position) public positions;

    mapping(TransactionType => uint256) public transactionNonces;

    mapping(bytes32 => uint256) public uintValues;
    mapping(bytes32 => int256) public intValues;
    mapping(bytes32 => address) public addressValues;
    mapping(bytes32 => bool) public boolValues;
    mapping(bytes32 => string) public stringValues;
    mapping(bytes32 => bytes32) public bytes32Values;
    
    mapping(uint256 => WithdrawHandler.Withdraw) public withdraws;
    
    bool public initialized;

    enum TransactionType {
        Deposit,
        Withdraw,
        Order,
        Position
    }

    constructor() Ownable(msg.sender) {}

    function initialize(address _owner) external {
        require(!initialized, "Already initialized");
        _transferOwnership(_owner);
        initialized = true;
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

    function setOpenInterest(address market, address collateralToken, uint256 amount) external {
        openInterest[market][collateralToken] = amount;
    }

    function getOpenInterest(address market, address collateralToken) external view returns (uint256) {
        return openInterest[market][collateralToken];
    }

    function setGlobalCumulativeFundingFee(address market, int256 amount) external {
        cumulativeFundingFee[market] = amount;
    }

    function getGlobalCumulativeFundingFee(address market) external view returns (int256) {
        return cumulativeFundingFee[market];
    }

    function setFundingFee(address market, int256 amount) external {
        fundingFee[market] = amount;
    }

    function getFundingFee(address market) external view returns (int256) {
        return fundingFee[market];
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

    function setPosition(bytes32 key, PositionHandler.Position memory position) external {
        positions[key] = position;
    }

    function getPosition(bytes32 key) external view returns (PositionHandler.Position memory) {
        return positions[key];
    }

    function getNonce(TransactionType _transactionType) external view returns (uint256) {
        return transactionNonces[_transactionType];
    }

    function incrementNonce(TransactionType _transactionType) external {
        transactionNonces[_transactionType]++;
    }

    function setWithdraw(uint256 key, WithdrawHandler.Withdraw memory withdraw) external {
        withdraws[key] = withdraw;
    }

    function getWithdraw(uint256 key) external view returns (WithdrawHandler.Withdraw memory) {
        return withdraws[key];
    }
}