// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, console} from "@test/utils/BBitsTestUtils.sol";

contract BBitsCheckInTest is BBitsTestUtils {

    function testInitialSettings() public view {
        assertTrue(checkIn.collections(address(basedBits)), "Initial collection should be set correctly");

        address[] memory collections = checkIn.getCollections();
        bool found = false;
        for (uint256 i = 0; i < collections.length; i++) {
            if (collections[i] == address(basedBits)) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Initial collection should be found in the collection list");
    }

    function testCheckIn() public {
        vm.prank(user0);
        checkIn.checkIn();

        (uint256 lastCheckIn, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 1);
        assertEq(count, 1);
        assertEq(lastCheckIn, block.timestamp);
    }

    function testCheckInStreak() public {
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 2);
        assertEq(count, 2);
    }

    function testStreakReset() public {
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 2.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 2.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 1);
        assertEq(count, 3);
    }

    function testStreakPreserve() public {
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 3);
        assertEq(count, 3);
    }

    function testFailCheckInTooSoon() public {
        vm.prank(user0);
        checkIn.checkIn();

        bool success;
        bytes memory data;

        // Try to check in again too soon and catch the revert
        (success, data) = address(checkIn).call(abi.encodeWithSignature("checkIn()"));

        // Assert that the call failed
        assertFalse(success, "Call should have failed");

        // Check the revert message
        if (data.length > 0) {
            // The revert reason is returned as a string
            string memory revertReason = abi.decode(data, (string));
            assertEq(revertReason, "Check-in too soon");
        }
    }

    function testFailCheckInNotEnoughNFTs() public {
        bool success;
        bytes memory data;

        // Ensure the user does not have enough NFTs
        assertFalse(checkIn.canCheckIn(user2), "User2 should not have enough NFTs");

        // Try to check in and catch the revert
        (success, data) = address(checkIn).call(abi.encodeWithSignature("checkIn()"));

        // Assert that the call failed
        assertFalse(success, "Call should have failed");

        // Check the revert message
        if (data.length > 0) {
            // The revert reason is returned as a string
            string memory revertReason = abi.decode(data, (string));
            assertEq(revertReason, "Not enough NFTs to check in");
        }
    }

    function testCanCheckInFalse() public {
        vm.prank(user2);
        assertFalse(checkIn.canCheckIn(user2));
    }

    function testCanCheckIn() public {
        vm.prank(user0);
        assertTrue(checkIn.canCheckIn(user0));
    }

    function testFailCheckInBanned() public {
        address bannedUser = address(0x2);
        checkIn.ban(bannedUser);

        bool success;
        bytes memory data;

        // Try to check in and catch the revert
        (success, data) = address(checkIn).call(abi.encodeWithSignature("checkIn()"));

        // Assert that the call failed
        assertFalse(success, "Call should have failed");

        // Check the revert message
        if (data.length > 0) {
            // The revert reason is returned as a string
            string memory revertReason = abi.decode(data, (string));
            assertEq(revertReason, "User is banned");
        }
    }

    function testFailCheckInPaused() public {
        checkIn.pause();

        bool success;
        bytes memory data;

        // Try to check in and catch the revert
        (success, data) = address(checkIn).call(abi.encodeWithSignature("checkIn()"));

        // Assert that the call failed
        assertFalse(success, "Call should have failed");

        // Check the revert message
        if (data.length > 0) {
            // The revert reason is returned as a string
            string memory revertReason = abi.decode(data, (string));
            assertEq(revertReason, "Pausable: paused");
        }
    }

    function testPauseContract() public {
        checkIn.pause();
        assertTrue(checkIn.paused());
    }

    function testUnpauseContract() public {
        checkIn.pause();
        checkIn.unpause();
        assertFalse(checkIn.paused());
    }

    function testBanUser() public {
        address bannedUser = address(0x2);
        checkIn.ban(bannedUser);
        assertTrue(checkIn.isBanned(bannedUser));
    }

    function testUnbanUser() public {
        address bannedUser = address(0x2);
        checkIn.ban(bannedUser);
        checkIn.unban(bannedUser);

        assertFalse(checkIn.isBanned(bannedUser));
    }

    function testAddAndRemoveCollection() public {
        address newCollection = address(0x3);

        checkIn.addCollection(newCollection);
        assertTrue(checkIn.collections(newCollection));

        checkIn.removeCollection(newCollection);
        assertFalse(checkIn.collections(newCollection));
    }

    function testFailAddExistingCollection() public {
        bool success;
        bytes memory data;

        // Ensure the collection exists
        assertTrue(checkIn.collections(address(basedBits)), "Initial collection should exist");

        // Try to add the existing collection and catch the revert
        (success, data) = address(checkIn).call(abi.encodeWithSignature("addCollection(address)", address(basedBits)));

        // Assert that the call failed
        assertFalse(success, "Call should have failed");

        // Check the revert message
        if (data.length > 0) {
            // The revert reason is returned as a string
            string memory revertReason = abi.decode(data, (string));
            assertEq(revertReason, "Collection already exists");
        }
    }

    function testFailAddCollectionNotOwner() public {
        vm.prank(user0);
        vm.expectRevert("Ownable: caller is not the owner");
        checkIn.addCollection(address(0x3));
    }

    function testOwnershipTransfer() public {
        checkIn.transferOwnership(user0);
        assertEq(checkIn.owner(), user0);
    }

    function testFailOwnershipTransferNotOwner() public {
        vm.prank(user0);
        vm.expectRevert("Ownable: caller is not the owner");
        checkIn.transferOwnership(user1);
    }
}