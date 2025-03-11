// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Bank.sol";
import "./MarketHandler.sol";
import "forge-std/Test.sol";

contract MarketToken is ERC20, Bank {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        console.log("Burning", amount, "from", from);
        console.log("Balance before", balanceOf(from));
        _burn(from, amount);
        console.log("Balance after", balanceOf(from));
    }
}