// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMarketFactory.sol";
import "./IDepositHandler.sol";
import "./IOrderHandler.sol";
import "./IPositionHandler.sol";
import "./IWithdrawHandler.sol";

interface IDataStore {
    enum TransactionType {
        Deposit,
        Withdraw,
        Order,
        Position
    }

    function initialize(address _owner) external;
    
    function setMarket(bytes32 key, IMarketFactory.Market memory market) external;
    function setMarketKey(address market, bytes32 key) external;
    function getMarketKey(address market) external view returns (bytes32);
    function getMarket(bytes32 key) external view returns (IMarketFactory.Market memory);
    
    function setOpenInterest(address market, address collateralToken, uint256 amount) external;
    function getOpenInterest(address market, address collateralToken) external view returns (uint256);
    
    function setGlobalCumulativeFundingFee(address market, int256 amount) external;
    function getGlobalCumulativeFundingFee(address market) external view returns (int256);
    
    function setFundingFee(address market, int256 amount) external;
    function getFundingFee(address market) external view returns (int256);
    
    function setDeposit(uint256 key, IDepositHandler.Deposit memory deposit) external;
    function getDeposit(uint256 key) external view returns (IDepositHandler.Deposit memory);
    
    function setOrder(uint256 key, IOrderHandler.Order memory order) external;
    function getOrder(uint256 key) external view returns (IOrderHandler.Order memory);
    
    function setPosition(bytes32 key, IPositionHandler.Position memory position) external;
    function getPosition(bytes32 key) external view returns (IPositionHandler.Position memory);
    
    function getNonce(TransactionType _transactionType) external view returns (uint256);
    function incrementNonce(TransactionType _transactionType) external;
    
    function setWithdraw(uint256 key, IWithdrawHandler.Withdraw memory withdraw) external;
    function getWithdraw(uint256 key) external view returns (IWithdrawHandler.Withdraw memory);
    
    // Public state variable getter functions that are automatically created for public mappings
    function markets(bytes32 key) external view returns (IMarketFactory.Market memory);
    function marketKeys(address market) external view returns (bytes32);
    function cumulativeFundingFee(address market) external view returns (int256);
    function fundingFee(address market) external view returns (int256);
    function openInterest(address market, address collateralToken) external view returns (uint256);
    function deposits(uint256 key) external view returns (IDepositHandler.Deposit memory);
    function orders(uint256 key) external view returns (IOrderHandler.Order memory);
    function positions(bytes32 key) external view returns (IPositionHandler.Position memory);
    function transactionNonces(TransactionType _transactionType) external view returns (uint256);
    function withdraws(uint256 key) external view returns (IWithdrawHandler.Withdraw memory);
    
    function uintValues(bytes32 key) external view returns (uint256);
    function intValues(bytes32 key) external view returns (int256);
    function addressValues(bytes32 key) external view returns (address);
    function boolValues(bytes32 key) external view returns (bool);
    function stringValues(bytes32 key) external view returns (string memory);
    function bytes32Values(bytes32 key) external view returns (bytes32);
    
    function initialized() external view returns (bool);
    function owner() external view returns (address);
}