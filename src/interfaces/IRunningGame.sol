// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DLL} from "@dll/DoublyLinkedList.sol";

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
        uint256 winner; /// Might be unnecessary also
        mapping(uint256 => Lap) laps;
        DLL positions; /// Head is the winner
    }

    struct Lap {
        uint256 startedAt;
        uint256 endedAt;
        uint256[] positionsAtLapEnd; 
        mapping(uint256 => bool) boosted;
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
    error InsufficientETHPaid();
    error WrongStatus();
    error MintingStillActive();
    error LapStillActive();
    error IsFinalLap();
    error FinalLapNotReached();
    error NotNFTOwner();
    error TransferFailed();
    error InvalidNode();
    error InvalidSetting();

    event GameStarted(uint256 indexed _raceId, uint256 _timestamp);
    event GameEnded(uint256 indexed _raceId, uint256 _timestamp);
    event LapStarted(uint256 indexed _raceId, uint256 indexed _lapId, uint256 _timestamp);
}
