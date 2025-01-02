// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LL} from "@mll/MemoryLinkedList.sol";

/// https://github.com/merklejerk/memory-linked-list
/// https://docs.google.com/document/d/10AesZM5kg7tM4OJB43hraZxLZA2YpqBTgUVOpuBK_Bo/edit?tab=t.0

interface IRunningGame {
    enum GameStatus {
        Pending,
        InMint,
        InRace
    }

    struct Race {
        uint256 startedAt;
        uint256 endedAt;
        uint256 prize; /// Winning amount - having already burned some amount
        uint256 winner;
        uint256 entries;
        mapping(uint256 => Lap) laps;
        LL positions; /// Head is the winner
    }

    struct Lap {
        uint256 startedAt;
        uint256 endedAt;
        uint256[] positionsAtLapEnd; 
        mapping(uint256 => bool) boosted;
    }

    /// @dev needs to be a struct for the linked list logic to work
    struct Runner {
        uint256 tokenId;
    }

    struct NamedBytes {
        bytes core;
        bytes name;
    }

    struct Set {
        uint256 background;
        /// @dev flesh out more
    }

    error InvalidPercentage();
    //error MintingTimeExceeded();
    //error LapTimeExceeded();
    error InsufficientETHPaid();
    error WrongStatus();

    error MintingStillActive();
    error LapStillActive();
    error IsFinalLap();
    error FinalLapNotReached();

    error NotInRace();
    error NotNFTOwner();

    error TransferFailed();
}
