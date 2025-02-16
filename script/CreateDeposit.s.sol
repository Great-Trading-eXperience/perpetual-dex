// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/DepositHandler.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateDepositScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address market = vm.envAddress("MARKET_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address depositVault = vm.envAddress("DEPOSIT_VAULT_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // First mint some tokens for testing
        MockToken(weth).mint(vm.addr(deployerPrivateKey), 10 * 10**18);

        // Then approve tokens
        IERC20(weth).approve(router, type(uint256).max);
        
        // Create deposit parameters
        DepositHandler.CreateDepositParams memory params = DepositHandler.CreateDepositParams({
            receiver: vm.addr(deployerPrivateKey),
            uiFeeReceiver: address(0),
            market: market,
            initialLongToken: weth,
            initialShortToken: usdc,
            minMarketTokens: 0,
            executionFee: 1 * 10**6
        });

        // Prepare multicall data
        bytes[] memory multicallData = new bytes[](2);

        // Send long token (WETH)
        multicallData[0] = abi.encodeWithSelector(
            Router.sendTokens.selector,
            weth,
            depositVault,
            1 * 10**18
        );

        // Create deposit
        multicallData[1] = abi.encodeWithSelector(
            Router.createDeposit.selector,
            params
        );

        Router(router).multicall(multicallData);

        console.log("Deposit created successfully");

        vm.stopBroadcast();
    }
}

interface MockToken {
    function mint(address account, uint256 amount) external;
} 