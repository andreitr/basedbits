// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";

contract MockSwapRouter is IV3Router {
    uint256 public returnAmount;
    uint256 public receivedETH;
    ExactInputSingleParams public lastParams;

    function setReturnAmount(uint256 _amount) external {
        returnAmount = _amount;
    }

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        returns (uint256 amountOut)
    {
        receivedETH = msg.value;
        lastParams = params;
        return returnAmount;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn) {
        return returnAmount;
    }
}
