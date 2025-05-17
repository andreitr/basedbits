// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, console, BBitsSocial} from "@test/utils/BBitsTestUtils.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";

/// @dev forge test --match-contract BBitsSocialTest -vvv
contract BBitsSocialTest is BBitsTestUtils {
    event Message(address indexed sender, string message, uint256 timestamp);
    event ThresholdUpdated(uint16 newThreshold, uint256 timestamp);
    event CharacterLimitUpdated(uint8 newThreshold, uint256 timestamp);

    function testInitialSettings() public {
        social = new BBitsSocial(address(checkIn), 8, 140, owner);
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

    function testCanPost() public {
        setCheckInStreak(user0, 11);
        vm.prank(user0);
        assertTrue(social.canPost(user0));
    }

    function testCanNotPost() public {
        setCheckInStreak(user0, 3);
        vm.prank(user0);
        assertFalse(social.canPost(user0));
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
        emit Message(user0, "Message 1", block.timestamp);
        social.post("Message 1");
        assertEq(social.posts(user0), 1);

        vm.expectEmit(true, true, true, true);
        emit Message(user0, "Message 2", block.timestamp);
        social.post("Message 2");
        assertEq(social.posts(user0), 2);
        vm.stopPrank();
    }

    function testPostMessageNotEnoughStreaks() public {
        setCheckInStreak(user0, 3);
        vm.prank(user0);
        vm.expectRevert('Not enough streaks to post');
        social.post("This should fail");
    }

    function testPostMessageTooManyCharacters() public {
        setCheckInStreak(user0, 22);
        vm.prank(user0);
        vm.expectRevert('Message exceeds character limit');
        social.post(
            "Today, I stumbled upon an old journal. Reading my past thoughts feels like meeting an old friend. Memories flood back, reminding me of who I am."
        );
    }

    function testPostMessageUserBanned() public {
        setCheckInStreak(user0, 22);
        setCheckInBan(user0);
        vm.prank(user0);
        vm.expectRevert('Account is banned from Based Bits');
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

    function testUpdateThresholdNotOwner() public {
        vm.prank(user0); // Acting as a non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        social.updateStreakThreshold(10);
    }

    function testUpdateCheckInContract() public {
        address newCheckInContract = address(0x2);
        social.updateCheckInContract(newCheckInContract);
        assertEq(social.checkInContract(), newCheckInContract);
    }

    function testUpdateCheckInContractNotOwner() public {
        address newCheckInContract = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        social.updateCheckInContract(newCheckInContract);
    }

    function testPause() public {
        social.pause();
        assertTrue(social.paused());
    }

    function testPauseNotOwner() public {
        vm.prank(user0); // Acting as a non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        social.pause();
    }

    function testUnpause() public {
        social.pause();
        social.unpause();
        assertFalse(social.paused());
    }

    function testUnpauseNotOwner() public {
        social.pause();
        vm.prank(user0); // Acting as a non-owner
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        social.unpause();
    }

    function testPostMessageWhenPaused() public {
        setCheckInStreak(user0, 22);
        social.pause();
        vm.prank(user0);
        vm.expectRevert(Pausable.EnforcedPause.selector);
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
