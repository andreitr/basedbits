// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IBBitsCheckIn} from "../../src/interfaces/IBBitsCheckIn.sol";

contract BBitsCheckInMock is IBBitsCheckIn {
    struct UserCheckIns {
        uint256 lastCheckIn;
        uint16 streak;
        uint16 count;
    }
    mapping(address => UserCheckIns) public checkIns;
    mapping(address => bool) public banned;

    function setStreak(address user, uint16 streak) external {
        checkIns[user].streak = streak;
    }

    function setBanned(address user) external {
        banned[user] = true;
    }

}
