// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Multicall.sol";
import "./DataStore.sol";
import "./DepositHandler.sol";
import "./OrderHandler.sol";

contract Router is Multicall {
    address public wnt;
    address public dataStore;
    address public depositHandler;
    address public withdrawHandler;
    address public orderHandler;

    error NotOwner();

    constructor(
        address _dataStore, 
        address _depositHandler, 
        address _withdrawHandler, 
        address _orderHandler,
        address _wnt
    ) {
        dataStore = _dataStore;
        depositHandler = _depositHandler;
        withdrawHandler = _withdrawHandler;
        orderHandler = _orderHandler;
        wnt = _wnt;
    }

    function sendWnt(address _receiver, uint256 _amount) external {
        IERC20(wnt).transferFrom(msg.sender, _receiver, _amount);
    }

    function sendTokens(address _token, address _receiver, uint256 _amount) external {
        IERC20(_token).transferFrom(msg.sender, _receiver, _amount);
    }

    function createDeposit(DepositHandler.CreateDepositParams memory _params) external {
       DepositHandler(depositHandler).createDeposit(dataStore, msg.sender, _params);
    }

    function cancelDeposit(uint256 _key) external {
        DepositHandler.Deposit memory deposit = DataStore(dataStore).getDeposit(_key);

        if (deposit.account != msg.sender) {
            revert NotOwner();
        }

        DepositHandler(depositHandler).cancelDeposit(dataStore, _key);
    }

    function createOrder(OrderHandler.CreateOrderParams memory _params) external {
        OrderHandler(orderHandler).createOrder(dataStore, msg.sender, _params);
    }

    function cancelOrder(uint256 _key) external {
        OrderHandler(orderHandler).cancelOrder(dataStore, _key);
    }
}
