// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBitsBurnerNFT {
    struct NamedBytes {
        bytes core;
        bytes name;
    }

    struct Set {
        uint256 background;
        uint256 body;
        uint256 eyes;
        uint256 hair;
        uint256 mouth;
    }

    error InsufficientETHPaid();
    error WETHDepositFailed();
    error InputZero();
    error InvalidArray();
    error InvalidIndex();
    error IndicesMustBeMonotonicallyDecreasing();
}
