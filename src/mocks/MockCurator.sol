// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../curator/Curator.sol";

contract MockCurator is Curator {
    constructor() Ownable(msg.sender) {}
}