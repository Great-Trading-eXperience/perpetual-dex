// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Router.sol";
import "../src/DepositHandler.sol";
import "../src/MarketFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreateDepositScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address router = vm.envAddress("ROUTER_ADDRESS");
        address market = vm.envAddress("MARKET_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address depositVault = vm.envAddress("DEPOSIT_VAULT_ADDRESS");
        
        uint256 executionFee = 1 * 10 ** 9;
        uint256 longTokenAmount = 1000 * 10 ** 18;
        uint256 shortTokenAmount = 3000 * 10 ** 18;

        vm.startBroadcast(deployerPrivateKey);

        // Mint both tokens
        MockToken(weth).mint(vm.addr(deployerPrivateKey), 10 * 10 ** 18);
        MockToken(usdc).mint(vm.addr(deployerPrivateKey), 3000 * 10 ** 18);

        // Approve both tokens to router
        IERC20(weth).approve(router, type(uint256).max);
        IERC20(usdc).approve(router, type(uint256).max);

        // Create deposit params
        DepositHandler.CreateDepositParams memory params = DepositHandler
            .CreateDepositParams({
                receiver: vm.addr(deployerPrivateKey),
                uiFeeReceiver: address(0),
                market: market,
                initialLongToken: weth,
                initialShortToken: usdc,
                minMarketTokens: 0,
                executionFee: executionFee
            });

        // Prepare multicall data
        bytes[] memory data = new bytes[](4);
        // 1. Transfer WNT for execution fee
        data[0] = abi.encodeCall(
            Router.sendWnt,
            (address(depositVault), executionFee)
        );

        // 2. Transfer long token (WETH)
        data[1] = abi.encodeCall(
            Router.sendTokens,
            (weth, address(depositVault), longTokenAmount)
        );

        // 3. Transfer short token (USDC)
        data[2] = abi.encodeCall(
            Router.sendTokens,
            (usdc, address(depositVault), shortTokenAmount)
        );

        // 4. Create deposit
        data[3] = abi.encodeCall(Router.createDeposit, (params));

        // Execute multicall
        Router(router).multicall(data);

        uint256 balanceOfMarketToken = IERC20(market).balanceOf(vm.addr(deployerPrivateKey));

        console.log("Balance of market token: %s", balanceOfMarketToken);

        vm.stopBroadcast();
    }
}

interface MockToken {
    function mint(address account, uint256 amount) external;
}
