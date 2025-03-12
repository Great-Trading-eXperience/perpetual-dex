// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Oracle.sol";

contract AddTokensToOracleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");

        // Get token addresses
        address weth = vm.envAddress("WETH_ADDRESS");
        address wbtc = vm.envAddress("WBTC_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address pepe = vm.envAddress("PEPE_ADDRESS");
        address doge = vm.envAddress("DOGE_ADDRESS");
        address trump = vm.envAddress("TRUMP_ADDRESS");
        address link = vm.envAddress("LINK_ADDRESS");

        // Set mock prices (in USD with 8 decimals)
        address signer = vm.envAddress("SIGNER_ADDRESS");
        uint256 minSigners = vm.envUint("MIN_SIGNERS");
        uint256 maxPriceAge = vm.envUint("MAX_PRICE_AGE");

        vm.startBroadcast(deployerPrivateKey);

        // Configure Oracle for all tokens
        address[] memory tokens = new address[](7);
        tokens[0] = weth;
        tokens[1] = wbtc;
        tokens[2] = usdc;
        tokens[3] = pepe;
        tokens[4] = doge;
        tokens[5] = trump;
        tokens[6] = link;

        for (uint i = 0; i < tokens.length; i++) {
            Oracle(oracle).setSigner(tokens[i], signer, true);
            Oracle(oracle).setMinSigners(tokens[i], minSigners);
            Oracle(oracle).setMaxPriceAge(tokens[i], maxPriceAge);

            console.log("Token %s configured in Oracle:", tokens[i]);
            console.log("- Signer: %s", signer);
            console.log("- Min Signers: %d", minSigners);
            console.log("- Max Price Age: %d", maxPriceAge);
        }

        vm.stopBroadcast();

        console.log("Token prices set in Oracle successfully");
    }
}