// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./AssetVault.sol";

abstract contract Curator is Ownable {
    using SafeERC20 for IERC20;
    
    // Curator information
    string public name;
    string public tokenURI;
    uint256 public feePercentage; // In basis points (1% = 100)
    bool public initialized;
    
    // Vaults created by this curator
    address[] public vaults;
    
    event VaultAdded(address indexed vault);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    
    modifier onlyInitialized() {
        require(initialized, "Not initialized");
        _;
    }
    
    function initialize(address _owner, string calldata _name, string calldata _tokenURI, uint256 _feePercentage) external {
        require(!initialized, "Already initialized");
        
        _transferOwnership(_owner);
        name = _name;
        tokenURI = _tokenURI;
        feePercentage = _feePercentage;
        initialized = true;
    }
    
    function updateFee(uint256 _newFeePercentage) external onlyOwner onlyInitialized {
        require(_newFeePercentage <= 1000, "Fee too high"); // Max 10%
        
        uint256 oldFee = feePercentage;
        feePercentage = _newFeePercentage;
        
        emit FeeUpdated(oldFee, _newFeePercentage);
    }
    
    function addVault(address _vault) external onlyOwner onlyInitialized {
        require(_vault != address(0), "Invalid vault address");
        vaults.push(_vault);
        
        emit VaultAdded(_vault);
    }
    
    function getVaults() external view returns (address[] memory) {
        return vaults;
    }

    function addMarketToVault(
        address vault,
        address market,
        uint256 weight
    ) external onlyOwner {
        require(vault != address(0), "Invalid vault address");
        require(market != address(0), "Invalid market address");
        require(weight > 0 && weight <= 10000, "Weight must be between 0 and 10000");
        
        // Cast vault address to AssetVault interface
        AssetVault(vault).addMarket(market, weight);
    }

    function updateMarketInVault(
        address vault,
        address market,
        uint256 weight,
        bool isActive
    ) external onlyOwner {
        require(vault != address(0), "Invalid vault address");
        require(market != address(0), "Invalid market address");
        require(weight <= 10000, "Weight must be between 0 and 10000");
        
        // Cast vault address to AssetVault interface and update the market
        AssetVault(vault).updateMarket(market, weight, isActive);
    }
}
