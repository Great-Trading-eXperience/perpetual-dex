// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWithdrawHandler {
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

    event WithdrawCreated(uint256 key, Withdraw withdraw);
    event WithdrawCancelled(uint256 key);
    event WithdrawExecuted(uint256 key);

    error InsufficientMarketTokenBalance();
    error InsufficientExecutionFee();
    error MarketDoesNotExist();

    function createWithdraw(address _account, CreateWithdrawParams memory _params) external returns (uint256);
    
    function cancelWithdraw(uint256 _key) external;
    
    function executeWithdraw(uint256 _key) external;

    // Public state variable getters
    function dataStore() external view returns (address);
    function withdrawVault() external view returns (address);
    function marketHandler() external view returns (address);
    function wnt() external view returns (address);
}