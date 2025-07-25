// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, console} from "@test/utils/BBitsTestUtils.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";

/// @dev forge test --match-contract BBitsCheckInTest -vvv
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

        uint256 timestamp = vm.getBlockTimestamp();
        vm.warp(timestamp += 2.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(timestamp += 2.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 1);
        assertEq(count, 3);
    }

    function testStreakPreserve() public {
        vm.prank(user0);
        checkIn.checkIn();

        uint256 timestamp = vm.getBlockTimestamp();
        vm.warp(timestamp += 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(timestamp += 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();

        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 3);
        assertEq(count, 3);
    }

    function testCheckInTooSoon() public {
        vm.startPrank(user0);
        checkIn.checkIn();

        vm.expectRevert("At least 24 hours must have passed since the last check-in or this is the first check-in");
        checkIn.checkIn();
        vm.stopPrank();
    }

    function testCheckInNotEnoughNFTs() public {
        assertFalse(checkIn.isEligible(user2), "User2 should not have enough NFTs");

        vm.prank(user2);
        vm.expectRevert("Must have at least one NFT from an allowed collection to check in");
        checkIn.checkIn();
    }

    function testIsEligibleFalse() public {
        vm.prank(user2);
        assertFalse(checkIn.isEligible(user2));
    }

    function testIsEligible() public {
        vm.prank(user0);
        assertTrue(checkIn.isEligible(user0));
    }

    function testCheckInBanned() public {
        checkIn.ban(user0);

        vm.prank(user0);
        vm.expectRevert("This address is banned from posting");
        checkIn.checkIn();
    }

    function testCheckInPaused() public {
        checkIn.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        checkIn.checkIn();
    }

    function testCanCheckInEligibleAndMoreThan24Hours() public {
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 1.01 days);
        assertTrue(checkIn.canCheckIn(user0), "User0 should be able to check in after 24 hours");
    }

    function testCanCheckInEligibleAndLessThan24Hours() public {
        vm.prank(user0);
        checkIn.checkIn();

        vm.warp(block.timestamp + 23 hours);
        assertFalse(checkIn.canCheckIn(user0), "User0 should not be able to check in before 24 hours");
    }

    function testCanCheckInNotEligible() public view {
        assertFalse(checkIn.canCheckIn(user2), "User2 should not be able to check in as they are not eligible");
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

    function testAddExistingCollection() public {
        // Ensure the collection exists
        assertTrue(checkIn.collections(address(basedBits)), "Initial collection should exist");

        // Try to add the existing collection and catch the revert
        vm.expectRevert("Collection already exists");
        checkIn.addCollection(address(basedBits));
    }

    function testAddCollectionNotOwner() public {
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        checkIn.addCollection(address(0x3));
    }

    function testOwnershipTransfer() public {
        checkIn.transferOwnership(user0);
        assertEq(checkIn.owner(), user0);
    }

    function testOwnershipTransferNotOwner() public {
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user0));
        checkIn.transferOwnership(user1);
    }
}
