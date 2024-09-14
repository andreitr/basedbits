// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBMintRaffleNFT {
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

    struct Entry {
        address user;
        uint256 weight;
    }

    struct Round {
        uint256 tokenId;
        uint256 winningId;
        uint256 mints;
        uint256 rewards;
        uint256 burned;
        address winner;
        uint256 startedAt;
        uint256 settledAt;
        Entry[] entries;
    }

    error CapExceeded();
    error InvalidArray();
    error InvalidIndex();
    error InvalidPercentage();
    error InputZero();
    error MustPayMintPrice();
    error TransferFailed();
    error IndicesMustBeMonotonicallyDecreasing();

    event Start(uint256 tokenId);
    event End(uint256 tokenId, uint256 mints, address winner, uint256 reward, uint256 burned);
}
