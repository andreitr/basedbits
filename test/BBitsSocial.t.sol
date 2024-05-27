// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    console,
    BBitsSocial
} from "./utils/BBitsTestUtils.sol";

contract BBitsSocialTest is BBitsTestUtils {
    event SocialPost(address indexed sender, string message, uint256 timestamp);
    event ThresholdUpdated(uint16 newThreshold, uint256 timestamp);
    event CharacterLimitUpdated(uint8 newThreshold, uint256 timestamp);

    function testInitialSettings() public {
        social = new BBitsSocial(8, address(checkIn), 140, owner);
        assertEq(social.streakThreshold(), 8);
        assertEq(social.checkInContract(), address(checkIn));
        assertEq(social.characterLimit(), 140);
    }

    function testPostMessage() public {
        setCheckInStreak(user0, 11);
        vm.prank(user0);
        social.post("Hello World!");
        assertEq(social.posts(user0), 1);
    }

    function testPostMessageWithUpdatedThreshold() public {
        setCheckInStreak(user0, 6);
        social.updateStreakThreshold(5);

        vm.prank(user0);
        social.post("Message 1");
    }

    function testPostMultipleMessages() public {
        setCheckInStreak(user0, 11);
        vm.startPrank(user0);

        vm.expectEmit(true, true, true, true);
        emit SocialPost(user0, "Message 1", block.timestamp);
        social.post("Message 1");
        assertEq(social.posts(user0), 1);

        vm.expectEmit(true, true, true, true);
        emit SocialPost(user0, "Message 2", block.timestamp);
        social.post("Message 2");
        assertEq(social.posts(user0), 2);
        vm.stopPrank();
    }

    function testFailPostMessageNotEnoughStreaks() public {
        setCheckInStreak(user0, 3);
        vm.prank(user0);
        social.post("This should fail");
    }

    function testFailPostMessageTooManyCharacters() public {
        setCheckInStreak(user0, 22);
        vm.prank(user0);
        social.post("Today, I stumbled upon an old journal. Reading my past thoughts feels like meeting an old friend. Memories flood back, reminding me of who I am.");
    }

    function testFailPostMessageUserBanned() public {
        setCheckInStreak(user0, 22);
        setCheckInBan(user0);
        vm.prank(user0);
        social.post("Test message");
    }

    function testUpdateThreshold() public {
        vm.expectEmit(true, true, true, true);
        emit ThresholdUpdated(10, block.timestamp);
        social.updateStreakThreshold(10);
        assertEq(social.streakThreshold(), 10);
    }

    function testEdgeCaseThreshold() public {
        social.updateStreakThreshold(type(uint16).max); // Set threshold to maximum value
        assertEq(social.streakThreshold(), type(uint16).max);

        social.updateStreakThreshold(0); // Set threshold to zero
        assertEq(social.streakThreshold(), 0);
    }

    function testFailUpdateThresholdNotOwner() public {
        vm.prank(user0); // Acting as a non-owner
        social.updateStreakThreshold(10);
    }

    function testUpdateCheckInContract() public {
        address newCheckInContract = address(0x2);
        social.updateCheckInContract(newCheckInContract);
        assertEq(social.checkInContract(), newCheckInContract);
    }

    function testFailUpdateCheckInContractNotOwner() public {
        address newCheckInContract = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        social.updateCheckInContract(newCheckInContract);
    }

    function testPause() public {
        social.pause();
        assertTrue(social.paused());
    }

    function testFailPauseNotOwner() public {
        vm.prank(user0); // Acting as a non-owner
        social.pause();
    }

    function testUnpause() public {
        social.pause();
        social.unpause();
        assertFalse(social.paused());
    }

    function testFailUnpauseNotOwner() public {
        social.pause();
        vm.prank(user0); // Acting as a non-owner
        social.unpause();
    }

    function testFailPostMessageWhenPaused() public {
        setCheckInStreak(user0, 22);
        social.pause();
        vm.prank(user0);
        social.post("This should fail");
    }

    function testOwnershipTransfer() public {
        social.transferOwnership(user0); // Transfer ownership to user
        assertTrue(social.owner() == user0);
    }

    function testUpdateCharacterLimit() public {
        assertEq(social.characterLimit(), 140);
        vm.expectEmit(true, true, true, true);
        emit CharacterLimitUpdated(240, block.timestamp);
        social.updateCharacterLimit(240);
        assertEq(social.characterLimit(), 240);
    }
}