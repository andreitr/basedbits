// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ISwapRouter} from "@src/PotRaider.sol";

contract MockSwapRouter is ISwapRouter {
    uint256 public returnAmount;
    uint256 public receivedETH;
    ExactInputSingleParams public lastParams;

    function setReturnAmount(uint256 _amount) external {
        returnAmount = _amount;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256 amountOut) {
        receivedETH = msg.value;
        lastParams = params;
        return returnAmount;
    }
}
