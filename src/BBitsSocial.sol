// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";

contract BBitsSocial is Ownable, Pausable {

    address public checkInContract;
    uint16 public streakThreshold;
    uint8 public characterLimit;

    mapping(address => uint256) public posts;

    event SocialPost(address indexed sender, string message, uint256 timestamp);
    event ThresholdUpdated(uint16 newThreshold, uint256 timestamp);
    event CharacterLimitUpdated(uint8 newThreshold, uint256 timestamp);

    constructor(uint16 _streakThreshold, address _checkInContractAddress, uint8 _characterLimit, address _initialOwner) Ownable(_initialOwner) {
        streakThreshold = _streakThreshold;
        checkInContract = _checkInContractAddress;
        characterLimit = _characterLimit;
    }

    function post(string memory message) public whenNotPaused {
        require(bytes(message).length < characterLimit, "Message exceeds character limit");

        IBBitsCheckIn check = IBBitsCheckIn(checkInContract);
        (, uint16 streak,) = check.checkIns(msg.sender);

        require(!check.banned(msg.sender), "Account is banned from Based Bits");
        require(streak >= streakThreshold, "Not enough streaks to post");

        posts[msg.sender]++;
        emit SocialPost(msg.sender, message, block.timestamp);
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
