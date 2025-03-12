// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/mocks/MockToken.sol";

contract DeployTokens is Script {
    uint256 constant INITIAL_SUPPLY = 1_000_000_000; // 1 billion base units

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy WETH with 18 decimals
        MockToken weth = new MockToken(
            "Wrapped Ether",
            "WETH",
            18
        );
        weth.mint(msg.sender, INITIAL_SUPPLY * 1e18);

         // Deploy WETH with 18 decimals
        MockToken wbtc = new MockToken(
            "Wrapped BTC",
            "WBTC",
            18
        );
        wbtc.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        // Deploy USDC with 6 decimals
        MockToken usdc = new MockToken(
            "USD Coin",
            "USDC",
            6
        );
        usdc.mint(msg.sender, INITIAL_SUPPLY * 1e6);

        // Deploy PEPE with 18 decimals
        MockToken pepe = new MockToken(
            "Pepe",
            "PEPE",
            18
        );
        pepe.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        // Deploy TRUMP with 18 decimals
        MockToken trump = new MockToken(
            "Trump Token",
            "TRUMP",
            18
        );
        trump.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        // Deploy DOGE with 18 decimals
        MockToken doge = new MockToken(
            "Dogecoin",
            "DOGE",
            8
        );
        doge.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        // Deploy LINK with 18 decimals
        MockToken link = new MockToken(
            "Chainlink",
            "LINK",
            18
        );
        link.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        MockToken shiba = new MockToken(
            "Shiba Inu",
            "SHIBA",
            18
        );
        shiba.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        MockToken bonk = new MockToken(
            "Bonk",
            "BONK",
            18
        );
        bonk.mint(msg.sender, INITIAL_SUPPLY * 1e18);

        MockToken floki = new MockToken(
            "Floki",
            "FLOKI",
            18
        );
        floki.mint(msg.sender, INITIAL_SUPPLY * 1e18);
        

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("WETH_ADDRESS=%s", address(weth));
        console.log("WBTC_ADDRESS=%s", address(wbtc));
        console.log("USDC_ADDRESS=%s", address(usdc));
        console.log("PEPE_ADDRESS=%s", address(pepe));
        console.log("TRUMP_ADDRESS=%s", address(trump));
        console.log("DOGE_ADDRESS=%s", address(doge));
        console.log("LINK_ADDRESS=%s", address(link));
        console.log("SHIBA_ADDRESS=%s", address(shiba));
        console.log("BONK_ADDRESS=%s", address(bonk));
        console.log("FLOKI_ADDRESS=%s", address(floki));
    }
} 