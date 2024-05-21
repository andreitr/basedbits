// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BBitsSocial.sol";
import {BBitsCheckInMock} from "./mocks/BBitsCheckInMock.sol";


contract BBitsSocialTest is Test {

    BBitsSocial public bbSocial;
    BBitsCheckInMock public checkin;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this); // Test contract is the owner
        user = address(0x1);

        checkin = new BBitsCheckInMock();
        bbSocial = new BBitsSocial(8, address(checkin), 140, owner);
    }

    function testInitialSettings() public {
        assertEq(bbSocial.streakThreshold(), 8);
        assertEq(bbSocial.checkInContract(), address(checkin));
        assertEq(bbSocial.characterLimit(), 140);
    }

    function testPostMessage() public {
        checkin.setStreak(user, 11);
        vm.prank(user);
        bbSocial.post("Hello World!");
        assertEq(bbSocial.posts(user), 1);
    }

    function testPostMessageWithUpdatedThreshold() public {
        checkin.setStreak(user, 6);
        bbSocial.updateStreakThreshold(5);

        vm.prank(user);
        bbSocial.post("Message 1");
    }

    function testPostMultipleMessages() public {
        checkin.setStreak(user, 11);
        vm.prank(user);

        bbSocial.post("Message 1");
        assertEq(bbSocial.posts(user), 1);

        vm.prank(user);
        bbSocial.post("Message 2");
        assertEq(bbSocial.posts(user), 2);
    }

    function testFailPostMessageNotEnoughStreaks() public {
        checkin.setStreak(user, 3);
        vm.prank(user);
        bbSocial.post("This should fail");
    }

    function testFailPostMessageTooManyCharacters() public {
        checkin.setStreak(user, 22);
        vm.prank(user);
        bbSocial.post("Today, I stumbled upon an old journal. Reading my past thoughts feels like meeting an old friend. Memories flood back, reminding me of who I am.");
    }

    function testFailPostMessageUserBanned() public {
        checkin.setStreak(user, 22);
        checkin.setBanned(user);
        vm.prank(user);
        bbSocial.post("Test message");
    }

    function testUpdateThreshold() public {
        bbSocial.updateStreakThreshold(10);
        assertEq(bbSocial.streakThreshold(), 10);
    }

    function testEdgeCaseThreshold() public {
        bbSocial.updateStreakThreshold(type(uint16).max); // Set threshold to maximum value
        assertEq(bbSocial.streakThreshold(), type(uint16).max);

        bbSocial.updateStreakThreshold(0); // Set threshold to zero
        assertEq(bbSocial.streakThreshold(), 0);
    }

    function testFailUpdateThresholdNotOwner() public {
        vm.prank(user); // Acting as a non-owner
        bbSocial.updateStreakThreshold(10);
    }

    function testUpdateCheckInContract() public {
        address newCheckInContract = address(0x2);
        bbSocial.updateCheckInContract(newCheckInContract);
        assertEq(bbSocial.checkInContract(), newCheckInContract);
    }

    function testFailUpdateCheckInContractNotOwner() public {
        address newCheckInContract = address(0x3);
        vm.prank(user); // Acting as a non-owner
        bbSocial.updateCheckInContract(newCheckInContract);
    }

    function testPause() public {
        bbSocial.pause();
        assertTrue(bbSocial.paused());
    }

    function testFailPauseNotOwner() public {
        vm.prank(user); // Acting as a non-owner
        bbSocial.pause();
    }

    function testUnpause() public {
        bbSocial.pause();
        bbSocial.unpause();
        assertFalse(bbSocial.paused());
    }

    function testFailUnpauseNotOwner() public {
        bbSocial.pause();
        vm.prank(user); // Acting as a non-owner
        bbSocial.unpause();
    }

    function testFailPostMessageWhenPaused() public {
        checkin.setStreak(user, 22);
        bbSocial.pause();
        vm.prank(user);
        bbSocial.post("This should fail");
    }

    function testOwnershipTransfer() public {
        bbSocial.transferOwnership(user); // Transfer ownership to user
        assertTrue(bbSocial.owner() == user);
    }
}