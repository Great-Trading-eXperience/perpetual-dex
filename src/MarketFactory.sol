// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketToken.sol";
import "./DataStore.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketFactory {
    event MarketCreated(
        string marketName,
        address indexed marketToken,
        address indexed longToken,
        address indexed shortToken
    );

    event MarketActivation(address indexed marketToken, Status status);

    error MarketAlreadyExists(address longToken, address shortToken);
    error MarketDoesNotExists(address longToken, address shortToken);

    struct Market {
        address marketToken;
        address longToken;
        address shortToken;
        Status status;
    }

    enum Status {
        INACTIVE,
        ACTIVE
    }

    address public dataStore;

    constructor(
        address _dataStore
    ) {
        dataStore = _dataStore;
    }

    function createMarket(address _longToken, address _shortToken) external returns (address) {
        string memory longSymbol = ERC20(_longToken).symbol();
        string memory shortSymbol = ERC20(_shortToken).symbol();
        string memory marketName = string.concat("GTX_", longSymbol, "_", shortSymbol);
        MarketToken marketToken = new MarketToken(marketName, marketName);
        Market memory existingMarket =
            DataStore(dataStore).getMarket(keccak256(abi.encodePacked(_longToken, _shortToken)));
        if (existingMarket.marketToken != address(0)) {
            revert MarketAlreadyExists(_longToken, _shortToken);
        }
        DataStore(dataStore).setMarket(
            keccak256(abi.encodePacked(_longToken, _shortToken)),
            Market({
                marketToken: address(marketToken),
                longToken: _longToken,
                shortToken: _shortToken,
                status: Status.INACTIVE
            })
        );

        DataStore(dataStore).setMarketKey(
            address(marketToken), keccak256(abi.encodePacked(_longToken, _shortToken))
        );

        emit MarketCreated(marketName, address(marketToken), _longToken, _shortToken);

        return address(marketToken);
    }

    function setMarketActivation(
        address _longToken,
        address _shortToken,
        Status _status
    ) external {
        bytes32 marketKey = keccak256(abi.encodePacked(_longToken, _shortToken));
        Market memory market = DataStore(dataStore).getMarket(marketKey);

        if (market.marketToken == address(0)) {
            revert MarketDoesNotExists(_longToken, _shortToken);
        }

        DataStore(dataStore).setMarket(
            marketKey,
            Market({
                marketToken: market.marketToken,
                longToken: _longToken,
                shortToken: _shortToken,
                status: _status
            })
        );

        emit MarketActivation(market.marketToken, _status);
    }
}
