// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBitsSocialRewards {
    enum RewardsStatus {
        PendingRound,
        InRound
    }

    struct Round {
        uint256 startedAt;
        uint256 settledAt;
        uint256 userReward;
        uint256 adminReward;
        uint256 entriesCount;
        uint256 rewardedCount;
        Entry[] entries;
    }

    struct Entry {
        bool approved;
        string post;
        address user;
        uint256 timestamp;
    }

    error AmountZero();
    error WrongStatus();
    error RoundActive();
    error RoundExpired();
    error InsufficientRewards();
    error InvalidPercentage();
    error IndexOutOfBounds();

    event Start(uint256 _roundId);
    event End(uint256 _roundId, uint256 _numberOfEntries, uint256 _userReward);
    event NewEntry(uint256 _roundId, uint256 indexed _entryId, address _user, string _link);
}
