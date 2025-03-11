// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./CuratorRegistry.sol";
import "./Curator.sol";

contract CuratorFactory is Ownable {
    using Clones for address;
    
    // Implementation contract to clone
    address public curatorImplementation;
    
    // Registry of approved curators
    CuratorRegistry public curatorRegistry;
    
    // Mapping from curator address to arrays of their deployed curator contract addresses
    mapping(address => address[]) public curatorContracts;
    
    // Events
    event CuratorContractDeployed(address indexed curator, address indexed curatorContract, string name);
    event ImplementationUpdated(address indexed newImplementation);
    
    constructor(address _curatorImplementation, address _curatorRegistry) Ownable(msg.sender) {
        require(_curatorImplementation != address(0), "Invalid implementation address");
        require(_curatorRegistry != address(0), "Invalid registry address");
        curatorImplementation = _curatorImplementation;
        curatorRegistry = CuratorRegistry(_curatorRegistry);
    }
    
    /**
     * @notice Deploy a new curator contract
     * @param _name Name of the curator contract
     * @param _tokenURI Token URI of the curator contract
     * @param _feePercentage Fee percentage charged by the curator (in basis points)
     * @return Address of the newly deployed curator contract
     */
    function deployCuratorContract(
        string calldata _name,
        string calldata _tokenURI,
        uint256 _feePercentage
    ) external returns (address) {
        require(curatorRegistry.isActiveCurator(msg.sender), "Not an active curator");
        
        // Create clone of the implementation
        address curatorContract = curatorImplementation.clone();
        
        Curator(curatorContract).initialize(
            msg.sender, 
            _name, 
            _tokenURI,
            _feePercentage
        );
        
        curatorContracts[msg.sender].push(curatorContract);
        
        emit CuratorContractDeployed(msg.sender, curatorContract, _name);
        
        return curatorContract;
    }
    

    function updateImplementation(address _newImplementation) external onlyOwner {
        require(_newImplementation != address(0), "Invalid implementation address");
        curatorImplementation = _newImplementation;
        
        emit ImplementationUpdated(_newImplementation);
    }
    
    function getCuratorContracts(address _curator) external view returns (address[] memory) {
        return curatorContracts[_curator];
    }
}
