// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    console,
    BBitsCheckIn,
    BBitsBadge7Day,
    BBitsBadges
} from "../utils/BBitsTestUtils.sol";

contract BBitsBadge7DayTest is BBitsTestUtils {

    function testInit() public {
        badge7DayMinter = new BBitsBadge7Day(checkIn, badges, 1, owner);
        assertEq(address(badge7DayMinter.checkInContract()), address(checkIn));
        assertEq(address(badge7DayMinter.badgeContract()), address(badges));
        assertEq(badge7DayMinter.tokenId(), 1);
    }

    function testMintSuccess() public {
        assertEq(badges.balanceOf(user0, 1), 0);
        assertEq(badge7DayMinter.minted(user0), false);
        setCheckInStreak(user0, 7);
        vm.prank(user0);
        badge7DayMinter.mint();
        assertEq(badges.balanceOf(user0, 1), 1);
        assertEq(badge7DayMinter.minted(user0), true);
    }

    function testSecondMintFailure() public {
        setCheckInStreak(user0, 7);
        vm.prank(user0);
        badge7DayMinter.mint();
        vm.expectRevert("User is not eligible to mint");
        badge7DayMinter.mint();
    }

    function testCanMint() public {
        // Low streak
        assertEq(badge7DayMinter.canMint(user1), false);

        // Can mint
        setCheckInStreak(user1, 7);
        assertEq(badge7DayMinter.canMint(user1), true);

        // Already minted
        vm.prank(user1);
        badge7DayMinter.mint();
        assertEq(badge7DayMinter.canMint(user1), false);
    }

    function testUpdateCheckInContract() public {
        assertEq(address(badge7DayMinter.checkInContract()), address(checkIn));
        BBitsCheckIn newCheckIn = new BBitsCheckIn(address(basedBits), owner);
        badge7DayMinter.updateCheckInContract(newCheckIn);
        assertEq(address(badge7DayMinter.checkInContract()), address(newCheckIn));
    }

    function testUpdateBadgeContract() public {
        assertEq(address(badge7DayMinter.badgeContract()), address(badges));
        BBitsBadges newbadges = new BBitsBadges(owner);
        badge7DayMinter.updateBadgeContract(newbadges);
        assertEq(address(badge7DayMinter.badgeContract()), address(newbadges));
    }

    function testUpdateBadgeTokenId() public {
        assertEq(badge7DayMinter.tokenId(), 1);
        badge7DayMinter.updateBadgeTokenId(4);
        assertEq(badge7DayMinter.tokenId(), 4);
    }
}