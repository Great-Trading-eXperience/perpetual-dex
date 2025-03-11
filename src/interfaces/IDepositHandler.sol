// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDepositHandler {
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

    event DepositCreated(uint256 key, Deposit deposit);
    event DepositCancelled(uint256 key);
    event DepositExecuted(uint256 key);

    error InsufficientExecutionFee();
    error MarketDoesNotExist();

    function createDeposit(address _account, CreateDepositParams memory _params) external returns (uint256);
    
    function cancelDeposit(uint256 _key) external;
    
    function executeDeposit(uint256 _key) external;

    // Public state variable getters
    function dataStore() external view returns (address);
    function depositVault() external view returns (address);
    function marketHandler() external view returns (address);
    function wnt() external view returns (address);
}