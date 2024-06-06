// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBBitsRaffle {
    enum RaffleStatus {
        PendingRaffle,    /// Raffle not started (just deployed/just settled)
        InRaffle,         /// Accepting entries
        PendingSettlement /// No longer accepting entries but not settled
    }

    struct Raffle {
        uint256 startedAt;
        uint256 settledAt;
        address[] entries;
        address winner;
        SponsoredPrize sponsoredPrize;
    }

    struct SponsoredPrize {
        uint256 tokenId;
        address sponsor;
    }

    error DepositZero();
    error WrongStatus();
    error NoBasedBitsToRaffle();
    error NotEligibleForFreeEntry();
    error RaffleExpired();
    error RaffleOnGoing();
    error AlreadyEnteredRaffle();
    error MustPayAntiBotFee();
    error SeedMustBeReset();
    error TransferFailed();
    error IndexOutOfBounds();

    event BasedBitsDeposited(address _sponsor, uint256 _tokenId);
    event NewRaffleStarted(uint256 _raffleId);
    event RaffleEntered(uint256 _raffleId, address _user);
    event RandomSeedSet(uint256 _raffleId, uint256 _seed);
    event RaffleSettled(uint256 _raffleId, address _winner, uint256 _tokenId);
}