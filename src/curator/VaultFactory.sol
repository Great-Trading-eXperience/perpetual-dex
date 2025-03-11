// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./CuratorRegistry.sol";
import "./Curator.sol";
import "./AssetVault.sol";

contract VaultFactory is Ownable {
    using Clones for address;
    
    address public vaultImplementation; 
    
    CuratorRegistry public curatorRegistry;
    
    mapping(address => address[]) public curatorVaults;
    
    address[] public allVaults;
        
    address public immutable router;
    address public immutable dataStore;
    address public immutable depositHandler;
    address public immutable depositVault;
    address public immutable withdrawVault;
    // Events
    event VaultDeployed(
        address indexed curator, 
        address indexed vault, 
        address indexed asset,
        string name
    );
    event ImplementationUpdated(address indexed newImplementation);
    
    constructor(
        address _vaultImplementation, 
        address _curatorRegistry,
        address _dataStore,
        address _router,
        address _depositHandler,
        address _depositVault,
        address _withdrawVault
    ) Ownable(msg.sender) {
        require(_vaultImplementation != address(0), "Invalid vault implementation");
        require(_curatorRegistry != address(0), "Invalid registry address");
        
        vaultImplementation = _vaultImplementation;
        curatorRegistry = CuratorRegistry(_curatorRegistry);
        
        router = _router;
        dataStore = _dataStore;
        depositHandler = _depositHandler;
        depositVault = _depositVault;
        withdrawVault = _withdrawVault;
    }
    
    function deployVault(
        address _curatorContract,
        address _asset,
        string calldata _name,
        string calldata _symbol
    ) external returns (address) {
        require(curatorRegistry.isActiveCurator(msg.sender), "Not an active curator");
        require(_asset != address(0), "Invalid asset address");
        
        // Determine which implementation to use based on asset type
        address implementation = vaultImplementation;
        
        // Create clone of the implementation
        address vault = implementation.clone();
        
        // Initialize the new vault
        AssetVault(vault).initialize(
            _curatorContract,
            _asset,
            _name,
            _symbol
        );
        
        // Store the new vault
        curatorVaults[msg.sender].push(vault);
        allVaults.push(vault);
        
        // Register vault with curator contract
        Curator(_curatorContract).addVault(vault);
        
        emit VaultDeployed(msg.sender, vault, _asset, _name);
        
        return vault;
    }
    
    function updateImplementation(address _newImplementation) external onlyOwner {
        require(_newImplementation != address(0), "Invalid implementation address");
        
        vaultImplementation = _newImplementation;
        
        emit ImplementationUpdated(_newImplementation);
    }
  
    function getCuratorVaults(address _curator) external view returns (address[] memory) {
        return curatorVaults[_curator];
    }

    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    function createVault(
        address curator,
        address asset,
        string memory name,
        string memory symbol,
        address marketFactory,
        address wnt
    ) external returns (address) {
        AssetVault vault = new AssetVault(
            router,
            dataStore,
            depositHandler,
            depositVault,
            withdrawVault,
            marketFactory,
            wnt
        );
        vault.initialize(curator, asset, name, symbol);
        return address(vault);
    }
}
