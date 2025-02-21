// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/Oracle.sol";

contract AddTokensToOracleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracle = vm.envAddress("ORACLE_ADDRESS");
        address weth = vm.envAddress("WETH_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address signer = vm.envAddress("SIGNER_ADDRESS");
        uint256 minSigners = vm.envUint("MIN_SIGNERS");
        uint256 maxPriceAge = vm.envUint("MAX_PRICE_AGE");

        vm.startBroadcast(deployerPrivateKey);

        // Configure Oracle for the new token
        Oracle(oracle).setSigner(weth, signer, true);
        Oracle(oracle).setSigner(usdc, signer, true);
        Oracle(oracle).setMinSigners(weth, minSigners);
        Oracle(oracle).setMinSigners(usdc, minSigners);
        Oracle(oracle).setMaxPriceAge(weth, maxPriceAge);
        Oracle(oracle).setMaxPriceAge(usdc, maxPriceAge);

        console.log("Token %s configured in Oracle:", weth);
        console.log("- Signer: %s", signer);
        console.log("- Min Signers: %d", minSigners);
        console.log("- Max Price Age: %d", maxPriceAge);

        vm.stopBroadcast();
    }
}