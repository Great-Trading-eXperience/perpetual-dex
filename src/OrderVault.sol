// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Bank.sol";

contract OrderVault is Bank {
    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function recordTransferIn(address _token) external returns (uint256) {
        uint256 previousBalance = tokenBalances[_token];
        uint256 newBalance = IERC20(_token).balanceOf(address(this));
        tokenBalances[_token] = newBalance;
        return newBalance - previousBalance;
    }
}
