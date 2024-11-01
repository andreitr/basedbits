// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBitsBurnerNFT {
    struct NamedBytes {
        bytes core;
        bytes name;
    }

    struct Set {
        uint256 background;
        uint256 redFire;
        uint256 orangeFire;
        uint256 yellowFire;
        uint256 noggles;
    }

    error InsufficientETHPaid();
    error WETHDepositFailed();
    error InputZero();
    error InvalidArray();
    error InvalidIndex();
    error IndicesMustBeMonotonicallyDecreasing();
}
