// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MarketToken is ERC20 {
    constructor() ERC20("GTX_MARKET", "GTX_MARKET") {}
}