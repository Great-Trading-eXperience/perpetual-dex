// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MarketFactory.sol";
import "../src/DataStore.sol";
import "../src/MarketToken.sol";
import "./mocks/MockToken.sol";
// import "../interfaces/IMarketFactory.sol";

contract MarketFactoryTest is Test {
    MarketFactory marketFactory;
    DataStore dataStore;
    address longToken;
    address shortToken;

    function setUp() public {
        dataStore = new DataStore();
        marketFactory = new MarketFactory(address(dataStore));
        longToken = address(new MockToken("Long Token", "LT", 18));
        shortToken = address(new MockToken("Short Token", "ST", 18));
    }

    function testCreateMarket() public {
        address marketTokenAddress = marketFactory.createMarket(longToken, shortToken);
        console.log("Market Token Address:", marketTokenAddress);
        assertTrue(marketTokenAddress != address(0), "Market token address should not be zero");
        bytes32 marketKey = keccak256(abi.encodePacked(longToken, shortToken));
        MarketFactory.Market memory market = dataStore.getMarket(marketKey);

        address marketToken = market.marketToken;
        console.log("Market Token Address:", marketToken);
        address longTokenAddress = market.longToken;
        console.log("Long Token Address:", longTokenAddress);
        address shortTokenAddress = market.shortToken;
        console.log("Short Token Address:", shortTokenAddress);
        MarketFactory.Status marketStatus = market.status;
        console.log("Market Status:", uint256(marketStatus));

        assertEq(marketToken, marketTokenAddress, "Market token address mismatch");
        assertEq(longTokenAddress, longToken, "Long token address mismatch");
        assertEq(shortTokenAddress, shortToken, "Short token address mismatch");
        assertEq(
            uint256(marketStatus),
            uint256(MarketFactory.Status.INACTIVE),
            "Market status should be INACTIVE"
        );
    }

    function testSetMarketActivation() public {
        marketFactory.createMarket(longToken, shortToken);
        marketFactory.setMarketActivation(longToken, shortToken, MarketFactory.Status.ACTIVE);

        bytes32 marketKey = keccak256(abi.encodePacked(longToken, shortToken));
        MarketFactory.Market memory market = dataStore.getMarket(marketKey);
        MarketFactory.Status status = market.status;

        assertEq(
            uint256(status), uint256(MarketFactory.Status.ACTIVE), "Market status should be ACTIVE"
        );
    }

    function testMarketAlreadyExists() public {
        marketFactory.createMarket(longToken, shortToken);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.MarketAlreadyExists.selector, longToken, shortToken
            )
        );
        marketFactory.createMarket(longToken, shortToken);
    }

    function testMarketDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketFactory.MarketDoesNotExists.selector, longToken, shortToken
            )
        );
        marketFactory.setMarketActivation(longToken, shortToken, MarketFactory.Status.ACTIVE);
    }
}
