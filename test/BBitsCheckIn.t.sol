// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, console} from "@test/utils/BBitsTestUtils.sol";

contract BBitsCheckInTest is BBitsTestUtils {
    function testInitialSettings() public view {
        assertEq(checkIn.collection(), address(basedBits));
    }

    function testCheckIn() public {
        vm.prank(user0);
        checkIn.checkIn();
        // Verify streak  count
        (, uint256 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 1);
        assertEq(count, 1);
    }

    function testCheckInStreak() public {
        vm.prank(user0);
        checkIn.checkIn();
        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();
        // Verify streak and check-in count
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
        // Verify streak count
        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 1);
        assertEq(count, 3);
    }

    function testStreakPreserveReset() public {
        vm.prank(user0);
        checkIn.checkIn();
        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();
        vm.warp(block.timestamp + 1.01 days);
        vm.prank(user0);
        checkIn.checkIn();
        // Verify streak count
        (, uint16 streak, uint16 count) = checkIn.checkIns(user0);
        assertEq(streak, 3);
        assertEq(count, 3);
    }

    function testFailCheckInTooSoon() public {
        vm.prank(user0);
        checkIn.checkIn();
        vm.prank(user0);
        checkIn.checkIn();
    }

    function testFailCheckInNotEnoughNFTs() public {
        vm.prank(user2);
        checkIn.checkIn();
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
        (bool s,) = address(basedBits).call(
            abi.encodeWithSelector(bytes4(keccak256("mintMany(address,uint256)")), bannedUser, 2)
        );
        assert(s);
        checkIn.ban(bannedUser);
        vm.prank(bannedUser);
        checkIn.checkIn();
    }

    function testFailCheckInPaused() public {
        checkIn.pause();
        vm.prank(user0);
        checkIn.checkIn();
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

    function testUpdateCollection() public {
        address newCollection = address(0x2);
        checkIn.updateCollection(newCollection);
        assertEq(checkIn.collection(), newCollection);
    }

    function testFailUpdateCollectionNotOwner() public {
        address newCollection = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        checkIn.updateCollection(newCollection);
    }

    function testPause() public {
        checkIn.pause();
        assertTrue(checkIn.paused());
    }

    function testFailPauseNotOwner() public {
        vm.prank(user0); // Acting as a non-owner
        checkIn.pause();
    }

    function testUnpause() public {
        checkIn.pause();
        checkIn.unpause();
        assertFalse(checkIn.paused());
    }

    function testFailUnpauseNotOwner() public {
        checkIn.pause();
        vm.prank(user0); // Acting as a non-owner
        checkIn.unpause();
    }

    function testOwnershipTransfer() public {
        checkIn.transferOwnership(user0); // Transfer ownership to user
        assertTrue(checkIn.owner() == user0);
    }
}
