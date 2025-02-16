// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../src/Router.sol";
import "../src/DepositHandler.sol";
import "../src/DepositVault.sol";
import "../src/DataStore.sol";
import "../src/MarketFactory.sol";
import "../src/MarketToken.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MOCK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract DepositTest is Test {
    Router public router;
    DepositHandler public depositHandler;
    DepositVault public depositVault;
    DataStore public dataStore;
    MarketFactory public marketFactory;
    MarketToken public marketToken;
    MockToken public wnt;
    MockToken public usdc;
    
    address user = address(1);

    function setUp() public {
        // Deploy contracts
        wnt = new MockToken();
        usdc = new MockToken();
        dataStore = new DataStore();
        depositVault = new DepositVault();
        depositHandler = new DepositHandler(address(depositVault), address(wnt));
        marketFactory = new MarketFactory(address(dataStore));
        
        router = new Router(
            address(dataStore),
            address(depositHandler),
            address(0), 
            address(0),
            address(wnt)
        );

        // Setup market
        address marketTokenAddress = marketFactory.createMarket(
            address(wnt),
            address(usdc)
        );

        marketToken = MarketToken(marketTokenAddress);

        // Fund user
        wnt.transfer(user, 100 * 10**18);
        usdc.transfer(user, 100 * 10**18);
        vm.deal(user, 100 ether);

        // Approve tokens
        vm.startPrank(user);
        wnt.approve(address(router), type(uint256).max);
        usdc.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function testCreateDepositUsingWnt() public {
        vm.startPrank(user);
        
        DepositHandler.CreateDepositParams memory params = DepositHandler.CreateDepositParams({
            receiver: user,
            uiFeeReceiver: address(0),
            market: address(marketToken),
            initialLongToken: address(wnt),
            initialShortToken: address(usdc),
            minMarketTokens: 0,
            executionFee: 1 * 10**6
        });

        bytes[] memory multicallData = new bytes[](3);

        // Send long token
        multicallData[0] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(wnt),
            address(depositVault),
            1 * 10**18
        );

        // Send short token
        multicallData[1] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            address(usdc),
            address(depositVault),
            1 * 10**18
        );

        // Create deposit
        multicallData[2] = abi.encodeWithSelector(
            Router.createDeposit.selector,
            params
        );

        router.multicall(multicallData);

        DepositHandler.Deposit memory deposit = dataStore.getDeposit(0);
        assertEq(deposit.account, user);
        assertEq(deposit.initialLongTokenAmount, 1 * 10**18 - 1 * 10**6);
        assertEq(deposit.initialShortTokenAmount, 1 * 10**18);

        vm.stopPrank();
    }

    function testCancelDeposit() public {
        testCreateDepositUsingWnt();

        vm.startPrank(user);
        
        router.cancelDeposit(0);

        DepositHandler.Deposit memory deposit = dataStore.getDeposit(0);
        assertEq(deposit.account, address(0)); // Deposit should be cleared
        assertEq(deposit.initialLongTokenAmount, 0);
        assertEq(deposit.initialShortTokenAmount, 0);
        
        vm.stopPrank();
    }
} 