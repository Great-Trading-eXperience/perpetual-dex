// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Bank {
    mapping (address => uint256) public tokenBalances;

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function transferOut(address _token, address _receiver, uint256 _amount) external {
        IERC20(_token).transfer(_receiver, _amount);
        tokenBalances[_token] -= _amount;
    }

    function syncBalance(address _token) external {
        tokenBalances[_token] = IERC20(_token).balanceOf(address(this));
    }
}
