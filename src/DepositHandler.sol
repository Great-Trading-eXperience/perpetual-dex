// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DepositVault.sol";
import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketHandler.sol";

contract DepositHandler {
    address public dataStore;
    address public depositVault;
    address public marketHandler;
    address public wnt;

    event DepositCreated(uint256 key, Deposit deposit);
    event DepositCancelled(uint256 key);
    event DepositExecuted(uint256 key);

    error InsufficientExecutionFee();
    error MarketDoesNotExist();

    struct CreateDepositParams {
        address receiver;
        address uiFeeReceiver;
        address market;
        address initialLongToken;
        address initialShortToken;
        uint256 minMarketTokens;
        uint256 executionFee;
    }

    struct Deposit {
        address account;
        address receiver;
        address uiFeeReceiver;
        address marketToken;
        address initialLongToken;
        address initialShortToken;
        uint256 executionFee;
        uint256 initialLongTokenAmount;
        uint256 initialShortTokenAmount;
    }

    constructor(address _dataStore, address _depositVault, address _marketHandler, address _wnt) {
        dataStore = _dataStore;
        depositVault = _depositVault;
        marketHandler = _marketHandler;
        wnt = _wnt;
    }

    function createDeposit(address _account, CreateDepositParams memory _params) external returns (uint256) {
        MarketFactory.Market memory market = DataStore(dataStore).getMarket(keccak256(abi.encodePacked(_params.initialLongToken, _params.initialShortToken)));

        if (market.marketToken == address(0)) {
            revert MarketDoesNotExist();
        }

        uint256 initialLongTokenAmount = DepositVault(depositVault).recordTransferIn(
            _params.initialLongToken
        );

        uint256 initialShortTokenAmount = DepositVault(depositVault).recordTransferIn(
            _params.initialShortToken
        );

        uint256 executionFeeAmount;
        
        if (_params.initialLongToken == wnt) {
            executionFeeAmount = _params.executionFee;
            initialLongTokenAmount -= executionFeeAmount;
        } else {
            executionFeeAmount = DepositVault(depositVault).recordTransferIn(wnt);
        }

        if (executionFeeAmount < _params.executionFee) {
            revert InsufficientExecutionFee();
        }

        uint256 nonce = DataStore(dataStore).getNonce(DataStore.TransactionType.Deposit);
        
        Deposit memory depositData = Deposit(
            _account,
            _params.receiver,
            _params.uiFeeReceiver,
            _params.market,
            _params.initialLongToken,
            _params.initialShortToken,
            _params.executionFee,
            initialLongTokenAmount,
            initialShortTokenAmount
        );

        DataStore(dataStore).setDeposit(
            nonce,
            depositData
        );

        DataStore(dataStore).incrementNonce(DataStore.TransactionType.Deposit);

        emit DepositCreated(nonce, depositData);

        return nonce;
    }

    function cancelDeposit( uint256 _key) external {
        Deposit memory deposit = DataStore(dataStore).getDeposit(_key);

        if(deposit.initialLongTokenAmount > 0) {    
            DepositVault(depositVault).transferOut(deposit.initialLongToken, deposit.receiver, deposit.initialLongTokenAmount);
        }

        if(deposit.initialShortTokenAmount > 0) {
            DepositVault(depositVault).transferOut(deposit.initialShortToken, deposit.receiver, deposit.initialShortTokenAmount);
        }

        DepositVault(depositVault).transferOut(wnt, deposit.receiver, deposit.executionFee);

        DataStore(dataStore).setDeposit(_key, Deposit({
            account: address(0),
            receiver: address(0),
            uiFeeReceiver: address(0),
            marketToken: address(0),
            initialLongToken: address(0),
            initialShortToken: address(0),
            executionFee: 0,
            initialLongTokenAmount: 0,
            initialShortTokenAmount: 0
        }));

        emit DepositCancelled(_key);
    }

    function executeDeposit(uint256 _key) external {
        Deposit memory deposit = DataStore(dataStore).getDeposit(_key);

        if(deposit.initialLongTokenAmount > 0) {   
            DepositVault(depositVault).transferOut(deposit.initialLongToken, deposit.marketToken, deposit.initialLongTokenAmount);
        }

        if(deposit.initialShortTokenAmount > 0) {
            DepositVault(depositVault).transferOut(deposit.initialShortToken, deposit.marketToken, deposit.initialShortTokenAmount);
        }

        DepositVault(depositVault).transferOut(wnt, msg.sender, deposit.executionFee);
        MarketHandler(marketHandler).handleDeposit(
            deposit.receiver,
            deposit.marketToken,
            deposit.initialLongTokenAmount,
            deposit.initialShortTokenAmount
        );

        DataStore(dataStore).setDeposit(_key, Deposit({
            account: address(0),
            receiver: address(0),
            uiFeeReceiver: address(0),
            marketToken: address(0),
            initialLongToken: address(0),
            initialShortToken: address(0),
            executionFee: 0,
            initialLongTokenAmount: 0,
            initialShortTokenAmount: 0
        }));

        emit DepositExecuted(_key);
    }
}
