// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";

/// @dev Quotes WETH<->USDC at a fixed rate (USDC per 1 ETH, 6 decimals).
contract MockV3Quoter is IV3Quoter {
    address public weth;
    uint256 public usdcPerEth;

    constructor(address _weth, uint256 _usdcPerEth) {
        weth = _weth;
        usdcPerEth = _usdcPerEth;
    }

    function setUsdcPerEth(uint256 _usdcPerEth) external {
        usdcPerEth = _usdcPerEth;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        view
        override
        returns (uint256 amountOut, uint160, uint32, uint256)
    {
        if (params.tokenIn == weth) {
            amountOut = (params.amountIn * usdcPerEth) / 1e18;
        } else {
            amountOut = (params.amountIn * 1e18) / usdcPerEth;
        }
        return (amountOut, 0, 0, 0);
    }

    function quoteExactOutputSingle(QuoteExactOutputSingleParams memory)
        external
        pure
        override
        returns (uint256, uint160, uint32, uint256)
    {
        revert("unsupported");
    }
}
