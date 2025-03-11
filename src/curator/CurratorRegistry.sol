// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title CuratorRegistry
 * @notice Registry for approved curators who can provide liquidity for perpetual trading
 */
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
    
    /**
     * @notice Add a new curator to the registry
     * @param _curatorAddress Address of the curator
     * @param _name Name of the curator
     */
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
    
    /**
     * @notice Deactivate a curator
     * @param _curatorAddress Address of the curator to deactivate
     */
    function deactivateCurator(address _curatorAddress) external onlyOwner {
        require(curators[_curatorAddress].curatorAddress != address(0), "Curator does not exist");
        require(curators[_curatorAddress].isActive, "Curator already inactive");
        
        curators[_curatorAddress].isActive = false;
        
        emit CuratorDeactivated(_curatorAddress);
    }
    
    /**
     * @notice Reactivate a curator
     * @param _curatorAddress Address of the curator to reactivate
     */
    function reactivateCurator(address _curatorAddress) external onlyOwner {
        require(curators[_curatorAddress].curatorAddress != address(0), "Curator does not exist");
        require(!curators[_curatorAddress].isActive, "Curator already active");
        
        curators[_curatorAddress].isActive = true;
        
        emit CuratorReactivated(_curatorAddress);
    }
    
    /**
     * @notice Check if an address is an active curator
     * @param _address Address to check
     * @return bool indicating if the address is an active curator
     */
    function isActiveCurator(address _address) external view returns (bool) {
        return curators[_address].isActive;
    }
    
    /**
     * @notice Get the total number of curators
     * @return uint256 Total number of curators
     */
    function getCuratorCount() external view returns (uint256) {
        return curatorAddresses.length;
    }
}
