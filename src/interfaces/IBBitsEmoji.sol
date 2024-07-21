// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBitsEmoji {
    struct NamedBytes {
        bytes core;
        bytes name;
    }

    struct Set {
        uint256 background1;
        uint256 background2;
        uint256 head;
        uint256 hair1;
        uint256 hair2;
        uint256 eyes1;
        uint256 eyes2;
        uint256 mouth1;
        uint256 mouth2;
    }

    struct Entry {
        address user;
        uint256 weight;
    }

    struct Day {
        uint256 tokenId;
        uint256 mints;
        uint256 rewards;
        uint256 burned;
        address winner;
        uint256 start;
        Entry[] entries;
    }

    error InvalidArray();
    error InvalidIndex();
    error InvalidPercentage();
    error InputZero();
    error MustPayMintPrice();
    error TransferFailed();

    event Raffle(uint256 tokenId, uint256 mints, address winner, uint256 reward, uint256 burned);
}