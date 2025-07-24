// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PotRaider} from "@src/PotRaider.sol";

/// @dev Minimal interface for performing a static call to Uniswap's Quoter
/// contract. The function itself is non-view on chain but we can safely invoke
/// it using `staticcall` to fetch the return data.
interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external view returns (uint256 amountOut);
}

/// @notice Utility script for checking the configured Uniswap V3 quoter.
/// @dev Reads the addresses stored in PotRaider and queries `quoteExactInputSingle`.
contract CheckQuoter is Script {
    function run() external {
        // Allow overriding the PotRaider address via the POT_RAIDER env variable
        address payable potRaiderAddress = payable(
            vm.envOr("POT_RAIDER", address(0x522e8E038f701FD33eB77cB76A8648a05954d9Dd))
        );
        uint256 amountIn = vm.envOr("AMOUNT_IN", uint256(1 ether));

        PotRaider potRaider = PotRaider(potRaiderAddress);
        address quoter = potRaider.uniswapQuoter();
        address tokenIn = potRaider.wethAddress();
        address tokenOut = potRaider.usdcContract();

        (bool success, bytes memory data) = quoter.staticcall(
            abi.encodeWithSelector(
                IQuoter.quoteExactInputSingle.selector,
                tokenIn,
                tokenOut,
                500,
                amountIn,
                0
            )
        );

        if (!success) {
            console.log("Quoter call failed");
            console.logBytes(data);
            return;
        }

        uint256 amountOut = abi.decode(data, (uint256));
        console.log("Quoted amount:", amountOut);
    }
}
