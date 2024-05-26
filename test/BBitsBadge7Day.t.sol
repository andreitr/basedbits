// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/BBitsBadge7Day.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {IBBitsBadges} from "../src/interfaces/IBBitsBadges.sol";
import {BBitsBadgesMock} from "./mocks/BBitsBadgesMock.sol";
import {BBitsCheckInMock} from "./mocks/BBitsCheckInMock.sol";

contract BBitsBadge7DayTest is Test {

    BBitsBadge7Day public badgeMinter;
    IBBitsBadges public collection;
    BBitsCheckInMock public checkin;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        collection = IBBitsBadges(address(new BBitsBadgesMock()));
        checkin = new BBitsCheckInMock();
        badgeMinter = new BBitsBadge7Day(address(checkin), address(collection), 1, owner);
    }

    function testMintWithSevenDayStreak() public {
        checkin.setStreak(user, 7);
        vm.prank(user);
        badgeMinter.mint();
        assertEq(collection.balanceOf(user, 1), 1);
    }

    function testCanMintWithSevenDayStreak() public {
        checkin.setStreak(user, 7);
        vm.prank(user);
        assertTrue(badgeMinter.canMint(user));
    }

    function testCantMint() public {
        checkin.setStreak(user, 3);
        vm.prank(user);
        assertFalse(badgeMinter.canMint(user));
    }

    function testMintWithTenDayStreak() public {
        checkin.setStreak(user, 10);
        vm.prank(user);
        badgeMinter.mint();
        assertEq(collection.balanceOf(user, 1), 1);
    }

    function testCorrectStreak() public {
        address testUser = address(0x2);

        checkin.setStreak(testUser, 10);
        (uint256 lastCheckIn, uint16 streak, uint16 count) = checkin.checkIns(testUser);
        assertEq(streak, 10);
    }

    function testFailMintWithoutSevenDayStreak() public {
        vm.prank(user);
        checkin.setStreak(user, 3);
        badgeMinter.mint();
    }

    function testUpdateCheckInAddressByOwner() public {
        address newAddress = address(0x2);
        badgeMinter.updateCheckInContract(newAddress);
        assertEq(badgeMinter.checkInContract(), newAddress);
    }

    function testFailUpdateCheckInAddressByNonOwner() public {
        address newAddress = address(0x2);
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateCheckInContract(newAddress);
    }

    function testUpdateBadgeCollectionAddressByOwner() public {
        address newAddress = address(0x3);
        badgeMinter.updateBadgeContract(newAddress);
        assertEq(badgeMinter.badgeContract(), newAddress);
    }

    function testFailUpdateBadgeCollectionAddressByNonOwner() public {
        address newAddress = address(0x3);
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateBadgeContract(newAddress);
    }

    function testUpdateBadgeTokenIdByOwner() public {
        uint256 newTokenId = 2;
        badgeMinter.updateBadgeTokenId(newTokenId);
        assertEq(badgeMinter.tokenId(), newTokenId);
    }

    function testFailUpdateBadgeTokenIdByNonOwner() public {
        uint256 newTokenId = 2;
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateBadgeTokenId(newTokenId);
    }

    function testSecondMintAfterAlreadyMinted() public {
        vm.startPrank(user);
        checkin.setStreak(user, 8);

        // First mint success
        assertEq(badgeMinter.canMint(user), true);
        badgeMinter.mint();

        // Second mint failure
        assertEq(badgeMinter.canMint(user), false);
        vm.expectRevert();
        badgeMinter.mint();
        vm.stopPrank();
    }
}
