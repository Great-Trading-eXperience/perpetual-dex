// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketToken.sol";
import "./DataStore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketFactory {
    event MarketCreated(address indexed marketToken, address indexed longToken, address indexed shortToken);

    error MarketAlreadyExists(address longToken, address shortToken);

    struct Market {
        address marketToken;
        address longToken;
        address shortToken;
    }

    address public dataStore;

    constructor(address _dataStore) {
        dataStore = _dataStore;
    }

    function createMarket(address _longToken, address _shortToken) external returns (address) {
        string memory longSymbol = ERC20(_longToken).symbol();
        string memory shortSymbol = ERC20(_shortToken).symbol();
        string memory marketName = string.concat("GTX_", longSymbol, "_", shortSymbol);
        MarketToken marketToken = new MarketToken(marketName, marketName);
        Market memory existingMarket = DataStore(dataStore).getMarket(keccak256(abi.encodePacked(_longToken, _shortToken)));
        if (existingMarket.marketToken != address(0)) {
            revert MarketAlreadyExists(_longToken, _shortToken);
        }
        DataStore(dataStore).setMarket(keccak256(abi.encodePacked(_longToken, _shortToken)), Market({
            marketToken: address(marketToken),
            longToken: _longToken,
            shortToken: _shortToken
        }));
        
        DataStore(dataStore).setMarketKey(address(marketToken), keccak256(abi.encodePacked(_longToken, _shortToken)));
        
        emit MarketCreated(address(marketToken), _longToken, _shortToken);
    
        return address(marketToken);
    }
}
