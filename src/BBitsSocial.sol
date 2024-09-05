// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";

contract BBitsSocial is Ownable, Pausable {
    address public checkInContract;
    uint16 public streakThreshold;
    uint16 public characterLimit;

    mapping(address => uint256) public posts;

    event Message(address indexed sender, string message, uint256 timestamp);
    event ThresholdUpdated(uint16 newThreshold, uint256 timestamp);
    event CharacterLimitUpdated(uint8 newThreshold, uint256 timestamp);

    constructor(address _checkInContractAddress, uint16 _streakThreshold, uint16 _characterLimit, address _initialOwner)
        Ownable(_initialOwner)
    {
        checkInContract = _checkInContractAddress;
        streakThreshold = _streakThreshold;
        characterLimit = _characterLimit;
    }

    function post(string memory message) public whenNotPaused {
        require(bytes(message).length < characterLimit, "Message exceeds character limit");

        IBBitsCheckIn check = IBBitsCheckIn(checkInContract);
        (, uint16 streak,) = check.checkIns(msg.sender);

        require(!check.banned(msg.sender), "Account is banned from Based Bits");
        require(streak >= streakThreshold, "Not enough streaks to post");

        posts[msg.sender]++;
        emit Message(msg.sender, message, block.timestamp);
    }

    function canPost(address user) public view returns (bool) {
        IBBitsCheckIn check = IBBitsCheckIn(checkInContract);
        (, uint16 streak,) = check.checkIns(user);

        return streak >= streakThreshold;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateCheckInContract(address newAddress) external onlyOwner {
        checkInContract = newAddress;
    }

    function updateCharacterLimit(uint8 limit) public onlyOwner {
        characterLimit = limit;
        emit CharacterLimitUpdated(limit, block.timestamp);
    }

    function updateStreakThreshold(uint16 threshold) public onlyOwner {
        streakThreshold = threshold;
        emit ThresholdUpdated(threshold, block.timestamp);
    }
}
