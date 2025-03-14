// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {DLL} from "@dll/DoublyLinkedList.sol";

interface IBaseRace {
    enum GameStatus {
        Pending,
        InMint,
        InRace
    }

    /// @dev Head of positions is the winner
    ///      Entries is the total number entered for the whole race
    struct Race {
        uint256 startedAt;
        uint256 endedAt;
        uint256 prize;
        uint256 winner;
        uint256 entries;
        uint256 lapCount;
        uint256 lapTotal;
        mapping(uint256 => Lap) laps;
        DLL positions;
    }

    struct Lap {
        uint256 startedAt;
        uint256 endedAt;
        uint256 eliminations;
        mapping(uint256 => bool) boosted;
        uint256[] positions;
    }

    /// @dev might be unnecessary here
    struct NamedBytes {
        bytes core;
        bytes name;
    }

    /// @dev flesh out more
    struct Set {
        uint256 background;
    }

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
    error HasBoosted();

    event GameStarted(uint256 indexed _raceId, uint256 _timestamp);
    event GameEnded(uint256 indexed _raceId, uint256 _timestamp);
    event LapStarted(uint256 indexed _raceId, uint256 indexed _lapId, uint256 _timestamp);
}
