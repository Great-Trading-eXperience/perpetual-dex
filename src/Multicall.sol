// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Multicall {

    error MulticallFailed(uint256 index, bytes reason);

    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                revert MulticallFailed(i, result);
            }

            results[i] = result;
        }

        return results;
    }
}
