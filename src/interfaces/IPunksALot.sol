// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPunksALot {
    struct NamedBytes {
        bytes core;
        bytes name;
    }

    struct Set {
        uint256 background;
        uint256 body;
        uint256 head;
        uint256 mouth;
        uint256 eyes;
    }

    error InsufficientETHPaid();
    error InputZero();
    error InvalidArray();
    error InvalidIndex();
    error IndicesMustBeMonotonicallyDecreasing();
    error CapExceeded();
    error TransferFailed();
    error InvalidPercentage();
    error NotNFTOwner();
}
