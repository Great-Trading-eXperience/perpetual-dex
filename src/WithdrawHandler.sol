// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./WithdrawVault.sol";
import "./DataStore.sol";
import "./MarketFactory.sol";
import "./MarketHandler.sol";

contract WithdrawHandler {
    address public dataStore;
    address public withdrawVault;
    address public marketHandler;
    address public wnt;

    event WithdrawCreated(uint256 key, Withdraw withdraw);
    event WithdrawCancelled(uint256 key);
    event WithdrawExecuted(uint256 key);

    error InsufficientMarketTokenBalance();
    error InsufficientExecutionFee();
    error MarketDoesNotExist();

    struct CreateWithdrawParams {
        address receiver;
        address uiFeeReceiver;
        address marketToken;
        address longToken;
        address shortToken;
        uint256 marketTokenAmount;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        uint256 executionFee;
    }

    struct Withdraw {
        address account;
        address receiver;
        address uiFeeReceiver;
        address marketToken;
        address longToken;
        address shortToken;
        uint256 marketTokenAmount;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        uint256 executionFee;
    }

    constructor(address _dataStore, address _withdrawVault, address _marketHandler, address _wnt) {
        dataStore = _dataStore;
        withdrawVault = _withdrawVault;
        marketHandler = _marketHandler;
        wnt = _wnt;
    }

    function createWithdraw(address _account, CreateWithdrawParams memory _params) external returns (uint256) {
        MarketFactory.Market memory market = DataStore(dataStore).getMarket(
            keccak256(abi.encodePacked(_params.longToken, _params.shortToken))
        );

        if (market.marketToken == address(0)) {
            revert MarketDoesNotExist();
        }

        // Transfer market tokens from user
        uint256 marketTokenBalanceBefore = WithdrawVault(withdrawVault).recordTransferIn(_params.marketToken);
        if (marketTokenBalanceBefore < _params.marketTokenAmount) {
            revert InsufficientMarketTokenBalance();
        }

        // Handle execution fee
        uint256 executionFeeAmount = WithdrawVault(withdrawVault).recordTransferIn(wnt);
        if (executionFeeAmount < _params.executionFee) {
            revert InsufficientExecutionFee();
        }

        uint256 nonce = DataStore(dataStore).getNonce(DataStore.TransactionType.Withdraw);
        
        Withdraw memory withdrawData = Withdraw(
            _account,
            _params.receiver,
            _params.uiFeeReceiver,
            _params.marketToken,
            _params.longToken,
            _params.shortToken,
            _params.marketTokenAmount,
            _params.longTokenAmount,
            _params.shortTokenAmount,
            _params.executionFee
        );

        DataStore(dataStore).setWithdraw(nonce, withdrawData);
        DataStore(dataStore).incrementNonce(DataStore.TransactionType.Withdraw);

        emit WithdrawCreated(nonce, withdrawData);

        return nonce;
    }

    function cancelWithdraw(uint256 _key) external {
        Withdraw memory withdraw = DataStore(dataStore).getWithdraw(_key);

        // Return market tokens to user
        WithdrawVault(withdrawVault).transferOut(
            withdraw.marketToken,
            withdraw.receiver,
            withdraw.marketTokenAmount
        );

        // Return execution fee
        WithdrawVault(withdrawVault).transferOut(
            wnt,
            withdraw.receiver,
            withdraw.executionFee
        );

        DataStore(dataStore).setWithdraw(_key, Withdraw({
            account: address(0),
            receiver: address(0),
            uiFeeReceiver: address(0),
            marketToken: address(0),
            longToken: address(0),
            shortToken: address(0),
            marketTokenAmount: 0,
            longTokenAmount: 0,
            shortTokenAmount: 0,
            executionFee: 0
        }));

        emit WithdrawCancelled(_key);
    }

    function executeWithdraw(uint256 _key) external {
        Withdraw memory withdraw = DataStore(dataStore).getWithdraw(_key);

        // Handle the withdrawal through market handler
        MarketHandler(marketHandler).handleWithdraw(
            withdraw.receiver,
            withdraw.marketToken,
            withdraw.marketTokenAmount,
            withdraw.longTokenAmount,
            withdraw.shortTokenAmount
        );

        // Burn market tokens
        MarketToken(withdraw.marketToken).burn(withdrawVault, withdraw.marketTokenAmount);

        // Pay execution fee to executor
        WithdrawVault(withdrawVault).transferOut(
            wnt,
            msg.sender,
            withdraw.executionFee
        );

        DataStore(dataStore).setWithdraw(_key, Withdraw({
            account: address(0),
            receiver: address(0),
            uiFeeReceiver: address(0),
            marketToken: address(0),
            longToken: address(0),
            shortToken: address(0),
            marketTokenAmount: 0,
            longTokenAmount: 0,
            shortTokenAmount: 0,
            executionFee: 0
        }));

        emit WithdrawExecuted(_key);
    }
} 