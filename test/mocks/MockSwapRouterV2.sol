// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {MockWETH} from "@test/mocks/MockWETH.sol";
import {MockERC20} from "@test/mocks/MockERC20.sol";

/// @dev Router mock that actually moves tokens at a fixed WETH<->USDC rate.
///      ETH->USDC: takes msg.value, mints USDC to recipient.
///      USDC->WETH: pulls USDC, wraps its own ETH into WETH for the recipient (fund it with vm.deal).
contract MockSwapRouterV2 is IV3Router {
    MockWETH public weth;
    MockERC20 public usdc;
    uint256 public usdcPerEth;

    uint256 public ethToUsdcCalls;
    uint256 public usdcToEthCalls;
    uint256 public lastUsdcToEthAmount;
    uint256 public totalUsdcToEth;
    bool public failSwaps;

    constructor(MockWETH _weth, MockERC20 _usdc, uint256 _usdcPerEth) {
        weth = _weth;
        usdc = _usdc;
        usdcPerEth = _usdcPerEth;
    }

    receive() external payable {}

    function setUsdcPerEth(uint256 _usdcPerEth) external {
        usdcPerEth = _usdcPerEth;
    }

    function setFailSwaps(bool _fail) external {
        failSwaps = _fail;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        require(!failSwaps, "MockSwapRouterV2: swap failed");
        if (params.tokenIn == address(weth)) {
            require(msg.value == params.amountIn, "MockSwapRouterV2: bad msg.value");
            amountOut = (params.amountIn * usdcPerEth) / 1e18;
            require(amountOut >= params.amountOutMinimum, "Too little received");
            usdc.mint(params.recipient, amountOut);
            ethToUsdcCalls++;
        } else {
            require(usdc.transferFrom(msg.sender, address(this), params.amountIn), "MockSwapRouterV2: pull failed");
            amountOut = (params.amountIn * 1e18) / usdcPerEth;
            require(amountOut >= params.amountOutMinimum, "Too little received");
            weth.deposit{value: amountOut}();
            require(weth.transfer(params.recipient, amountOut), "MockSwapRouterV2: weth transfer failed");
            usdcToEthCalls++;
            lastUsdcToEthAmount = params.amountIn;
            totalUsdcToEth += params.amountIn;
        }
    }

    function exactOutputSingle(ExactOutputSingleParams calldata) external payable override returns (uint256) {
        revert("unsupported");
    }
}
