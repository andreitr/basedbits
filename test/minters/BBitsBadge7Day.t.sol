// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, console} from "../utils/BBitsTestUtils.sol";

contract BBitsBadge7DayTest is BBitsTestUtils {

    function testMintWithSevenDayStreak() public {
        setCheckInStreak(user0, 7);
        vm.prank(user0);
        badge7DayMinter.mint();
        assertEq(badges.balanceOf(user0, 1), 1);
    }

    function testCanMintWithSevenDayStreak() public {
        setCheckInStreak(user0, 7);
        vm.prank(user0);
        assertTrue(badge7DayMinter.canMint(user0));
    }

    function testCantMint() public {
        setCheckInStreak(user0, 3);
        vm.prank(user0);
        assertFalse(badge7DayMinter.canMint(user0));
    }

    function testMintWithTenDayStreak() public {
        setCheckInStreak(user0, 10);
        vm.prank(user0);
        badge7DayMinter.mint();
        assertEq(badges.balanceOf(user0, 1), 1);
    }

    function testCorrectStreak() public {
        setCheckInStreak(user1, 10);
        (, uint16 streak,) = checkIn.checkIns(user1);
        assertEq(streak, 10);
    }

    function testFailMintWithoutSevenDayStreak() public {
        vm.prank(user0);
        setCheckInStreak(user0, 3);
        badge7DayMinter.mint();
    }

    function testUpdateCheckInAddressByOwner() public {
        address newAddress = address(0x3);
        badge7DayMinter.updateCheckInContract(newAddress);
        assertEq(badge7DayMinter.checkInContract(), newAddress);
    }

    function testFailUpdateCheckInAddressByNonOwner() public {
        address newAddress = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        badge7DayMinter.updateCheckInContract(newAddress);
    }

    function testUpdateBadgeCollectionAddressByOwner() public {
        address newAddress = address(0x3);
        badge7DayMinter.updateBadgeContract(newAddress);
        assertEq(badge7DayMinter.badgeContract(), newAddress);
    }

    function testFailUpdateBadgeCollectionAddressByNonOwner() public {
        address newAddress = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        badge7DayMinter.updateBadgeContract(newAddress);
    }

    function testUpdateBadgeTokenIdByOwner() public {
        uint256 newTokenId = 2;
        badge7DayMinter.updateBadgeTokenId(newTokenId);
        assertEq(badge7DayMinter.tokenId(), newTokenId);
    }

    function testFailUpdateBadgeTokenIdByNonOwner() public {
        uint256 newTokenId = 2;
        vm.prank(user0); // Acting as a non-owner
        badge7DayMinter.updateBadgeTokenId(newTokenId);
    }

    function testSecondMintAfterAlreadyMinted() public {
        setCheckInStreak(user0, 8);
        vm.startPrank(user0);

        // First mint success
        assertEq(badge7DayMinter.canMint(user0), true);
        badge7DayMinter.mint();

        // Second mint failure
        assertEq(badge7DayMinter.canMint(user0), false);
        vm.expectRevert();
        badge7DayMinter.mint();
        vm.stopPrank();
    }
}
