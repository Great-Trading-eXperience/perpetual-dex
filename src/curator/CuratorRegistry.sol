// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CuratorRegistry is Ownable {
    // Struct to store curator information
    struct CuratorInfo {
        string name;
        string uri;
        address curatorAddress;
        bool isActive;
        uint256 creationTime;
    }
    
    // Mapping from curator address to their information
    mapping(address => CuratorInfo) public curators;
    
    // Array to keep track of all curator addresses
    address[] public curatorAddresses;
    
    // Events
    event CuratorAdded(address indexed curatorAddress, string name);
    event CuratorDeactivated(address indexed curatorAddress);
    event CuratorReactivated(address indexed curatorAddress);
    
    constructor() Ownable(msg.sender) {}
    
    function addCurator(address _curatorAddress, string calldata _name, string calldata _uri) external onlyOwner {
        require(_curatorAddress != address(0), "Invalid address");
        require(curators[_curatorAddress].curatorAddress == address(0), "Curator already exists");
        
        CuratorInfo memory newCurator = CuratorInfo({
            name: _name,
            uri: _uri,
            curatorAddress: _curatorAddress,
            isActive: true,
            creationTime: block.timestamp
        });
        
        curators[_curatorAddress] = newCurator;
        curatorAddresses.push(_curatorAddress);
        
        emit CuratorAdded(_curatorAddress, _name);
    }
    
    function deactivateCurator(address _curatorAddress) external onlyOwner {
        require(curators[_curatorAddress].curatorAddress != address(0), "Curator does not exist");
        require(curators[_curatorAddress].isActive, "Curator already inactive");
        
        curators[_curatorAddress].isActive = false;
        
        emit CuratorDeactivated(_curatorAddress);
    }
    
    function reactivateCurator(address _curatorAddress) external onlyOwner {
        require(curators[_curatorAddress].curatorAddress != address(0), "Curator does not exist");
        require(!curators[_curatorAddress].isActive, "Curator already active");
        
        curators[_curatorAddress].isActive = true;
        
        emit CuratorReactivated(_curatorAddress);
    }
    
    function isActiveCurator(address _address) external view returns (bool) {
        return curators[_address].isActive;
    }
    
    function getCuratorCount() external view returns (uint256) {
        return curatorAddresses.length;
    }
}
