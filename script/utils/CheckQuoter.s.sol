// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PotRaider} from "@src/PotRaider.sol";

interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

/// @notice Utility script for checking the configured Uniswap V3 quoter.
/// @dev Reads the addresses stored in PotRaider and queries `quoteExactInputSingle`.
contract CheckQuoter is Script {
    function run() external {
        // Set the PotRaider address via the POT_RAIDER env variable
        address payable potRaiderAddress = payable(vm.envAddress("POT_RAIDER"));
        uint256 amountIn = vm.envOr("AMOUNT_IN", uint256(1 ether));

        vm.startBroadcast();

        PotRaider potRaider = PotRaider(potRaiderAddress);
        address quoter = potRaider.uniswapQuoter();
        address tokenIn = potRaider.wethAddress();
        address tokenOut = potRaider.usdcContract();

        try IQuoter(quoter).quoteExactInputSingle(tokenIn, tokenOut, 500, amountIn, 0) returns (uint256 amountOut) {
            console.log("Quoted amount:", amountOut);
        } catch (bytes memory err) {
            console.log("Quoter reverted with:");
            console.logBytes(err);
        }

        vm.stopBroadcast();
    }
}
