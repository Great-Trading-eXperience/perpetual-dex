// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDepositHandler.sol";
import "./IOrderHandler.sol";
import "./IPositionHandler.sol";
import "./IWithdrawHandler.sol";
import "./IMarketFactory.sol";

interface IRouter {
    error NotOwner();

    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
    
    function sendWnt(address _receiver, uint256 _amount) external;
    
    function sendTokens(address _token, address _receiver, uint256 _amount) external;
    
    function createDeposit(IDepositHandler.CreateDepositParams memory _params) external;
    
    function cancelDeposit(uint256 _key) external;
    
    function createOrder(IOrderHandler.CreateOrderParams memory _params) external;
    
    function cancelOrder(uint256 _key) external;
    
    function liquidatePosition(IPositionHandler.LiquidatePositionParams memory _params) external;
    
    function createWithdraw(IWithdrawHandler.CreateWithdrawParams memory _params) external returns (uint256);
    
    function cancelWithdraw(uint256 _key) external;
    
    // Public state variable getters
    function wnt() external view returns (address);
    function dataStore() external view returns (address);
    function depositHandler() external view returns (address);
    function withdrawHandler() external view returns (address);
    function orderHandler() external view returns (address);
    function positionHandler() external view returns (address);
}