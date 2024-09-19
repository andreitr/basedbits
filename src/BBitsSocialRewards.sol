// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IBBitsSocialRewards} from "@src/interfaces/IBBitsSocialRewards.sol";

contract BBitsSocialRewards is ReentrancyGuard, Pausable, Ownable, IBBitsSocialRewards {
    /// @notice Based Bits fungible token.
    IERC20 public immutable BBITS;

    /// @notice The current rewards status of this contract.
    ///         PendingRound:     Round not started (just deployed/just settled and contract without BBs).
    ///         InRound:          Accepting entries.
    RewardsStatus public status;

    /// @notice The total number of rounds held by this contract.
    /// @dev    Also used to identify the current round.
    uint256 public count;

    /// @notice Length of time that a round lasts.
    uint256 public duration;

    /// @notice The sum of BBITS used as incentives per round.
    uint256 public totalRewardsPerRound;

    /// @notice Reward percentage awarded to users who post links.
    /// @dev    10_000 = 100%
    uint256 public rewardPercentage;

    /// @notice Round information, including all entries.
    mapping(uint256 => Round) public round;

    constructor(address _owner, IERC20 _BBITS) Ownable(_owner) {
        BBITS = _BBITS;
        status = RewardsStatus.PendingRound;
        count = 0;
        duration = 7 days;
        totalRewardsPerRound = 1024e18;
        rewardPercentage = 9000;
    }

    /// EXTERNAL ///

    function submitPost(string calldata _link) external nonReentrant whenNotPaused {
        if (status != RewardsStatus.InRound) revert WrongStatus();
        if (block.timestamp - round[count].startedAt > duration) revert RoundExpired();
        Entry memory userEntry = Entry({approved: false, post: _link, user: msg.sender, timestamp: block.timestamp});
        round[count].entries.push(userEntry);
        round[count].entriesCount++;
        emit NewEntry(count, round[count].entriesCount, msg.sender, _link);
    }

    function depositBBITS(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert AmountZero();
        BBITS.transferFrom(msg.sender, address(this), _amount);
    }

    /// OWNER ///

    function approvePosts(uint256[] calldata _entryIds) external nonReentrant onlyOwner {
        if (status != RewardsStatus.InRound) revert WrongStatus();
        uint256 length = _entryIds.length;
        for (uint256 i; i < length; i++) {
            if (_entryIds[i] >= round[count].entries.length) revert IndexOutOfBounds();
            round[count].entries[_entryIds[i]].approved = true;
        }
        round[count].rewardedCount += length;
    }

    function settleCurrentRound() external nonReentrant onlyOwner {
        if (status != RewardsStatus.InRound) revert WrongStatus();
        if (block.timestamp - round[count].startedAt <= duration) revert RoundActive();
        _settle();
    }

    function startNextRound() external nonReentrant onlyOwner {
        if (status != RewardsStatus.PendingRound) revert WrongStatus();
        if (BBITS.balanceOf(address(this)) <= totalRewardsPerRound) revert InsufficientRewards();
        _startNextRound();
    }

    function setPaused(bool _setPaused) external onlyOwner {
        _setPaused ? _pause() : _unpause();
    }

    function setDuration(uint256 _newDuration) external onlyOwner {
        duration = _newDuration;
    }

    function setTotalRewardsPerRound(uint256 _newTotalRewardsPerRound) external onlyOwner {
        totalRewardsPerRound = _newTotalRewardsPerRound;
    }

    function setRewardPercentage(uint256 _newRewardPercentage) external onlyOwner {
        if (_newRewardPercentage > 10_000) revert InvalidPercentage();
        rewardPercentage = _newRewardPercentage;
    }

    /// VIEW ///

    function getEntryInfoForId(uint256 _round, uint256 _entryId) external view returns (Entry memory entry) {
        if (_entryId >= round[_round].entries.length) revert IndexOutOfBounds();
        entry = round[_round].entries[_entryId];
    }

    /// INTERNAL ///

    function _settle() internal {
        uint256 userRewards;
        uint256 adminReward = totalRewardsPerRound;
        uint256 rewardedCount = round[count].rewardedCount;
        if (rewardedCount != 0) {
            uint256 totalUserRewards = (totalRewardsPerRound * rewardPercentage) / 10_000;
            userRewards = totalUserRewards / rewardedCount;
            adminReward = totalRewardsPerRound - totalUserRewards;
            uint256 length = round[count].entriesCount;
            for (uint256 i; i < length; i++) {
                if (round[count].entries[i].approved) BBITS.transfer(round[count].entries[i].user, userRewards);
            }
            BBITS.transfer(owner(), totalRewardsPerRound - (userRewards * rewardedCount));
        }
        round[count].settledAt = block.timestamp;
        round[count].userReward = userRewards;
        round[count].adminReward = adminReward;
        status = RewardsStatus.PendingRound;
        emit End(count, round[count].entriesCount, userRewards);
    }

    function _startNextRound() internal {
        round[++count].startedAt = block.timestamp;
        status = RewardsStatus.InRound;
        emit Start(count);
    }
}
