// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IRunningGame {
    enum GameStatus {
        Pending,
        InMint,
        InRace
    }

    struct Race {
        uint256 entries; /// number of entries
        uint256 startedAt;
        uint256 endedAt;
        uint256 prize; /// Winning amount - having already burned some amount?
        uint256 winner;
        uint256 currentLap;
    }

    struct Lap {
        uint256 startedAt;
        uint256 endedAt;
        uint256[] positions; /// @dev Have to ensure is exposed
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

    /*
    error InputZero();
    error InvalidArray();
    error InvalidIndex();
    error IndicesMustBeMonotonicallyDecreasing();
    error CapExceeded();
    error TransferFailed();
    */
}
