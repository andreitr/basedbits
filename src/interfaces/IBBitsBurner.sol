// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBitsBurner {
    struct SwapParams {
        uint8 pool;
        uint24 fee;
    }

    error InValidPoolParams();
    error WETHDepositFailed();
    error BuyZero();
}
