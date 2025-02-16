// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderVault {
    mapping (address => uint256) public tokenBalances;

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function recordTransferIn(address _token) external returns (uint256) {
        uint256 previousBalance = tokenBalances[_token];
        uint256 newBalance = IERC20(_token).balanceOf(address(this));
        tokenBalances[_token] = newBalance;
        return newBalance - previousBalance;
    }

    function transferOut(address _token, uint256 _amount) external {
        IERC20(_token).transfer(msg.sender, _amount);
        tokenBalances[_token] -= _amount;
    }
}
