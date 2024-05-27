// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    console,
    BBitsCheckIn,
    BBitsBadges,
    BBitsBadgeBearPunk
} from "../utils/BBitsTestUtils.sol";

contract BBitsBadgeBearPunkTest is BBitsTestUtils {

    uint256 constant tokenId = 0x0000000000000000000000000000000000000000000000000000000000000003;

    function testInit() public {
        badgeBearPunkMinter = new BBitsBadgeBearPunk(bearPunks, checkIn, badges, 3, owner);
        assertEq(address(badgeBearPunkMinter.bearPunks()), address(bearPunks));
        assertEq(address(badgeBearPunkMinter.checkInContract()), address(checkIn));
        assertEq(address(badgeBearPunkMinter.badgeContract()), address(badges));
        assertEq(badgeBearPunkMinter.tokenId(), tokenId);
    }

    function testMintSuccess() public {
        assertEq(badges.balanceOf(user0, tokenId), 0);
        assertEq(badgeBearPunkMinter.minted(user0), false);
        setCheckInStreak(user0, 7);
        vm.prank(user0);
        badgeBearPunkMinter.mint();
        assertEq(badges.balanceOf(user0, tokenId), 1);
        assertEq(badgeBearPunkMinter.minted(user0), true);
    }

    function testSecondMintFailure() public {
        setCheckInStreak(user0, 7);
        vm.startPrank(user0);
        badgeBearPunkMinter.mint();
        vm.expectRevert("User is not eligible to mint");
        badgeBearPunkMinter.mint();
        vm.stopPrank();
    }

    function testCanMint() public {
        // Low streak
        assertEq(badgeBearPunkMinter.canMint(user1), false);

        // No bear punk
        setCheckInStreak(user1, 7);
        assertEq(badgeBearPunkMinter.canMint(user1), false);

        // Can mint
        bearPunks.mint(user1);
        assertEq(badgeBearPunkMinter.canMint(user1), true);

        // Already minted
        vm.prank(user1);
        badgeBearPunkMinter.mint();
        assertEq(badgeBearPunkMinter.canMint(user1), false);
    }

    function testUpdateCheckInContract() public {
        assertEq(address(badgeBearPunkMinter.checkInContract()), address(checkIn));
        BBitsCheckIn newCheckIn = new BBitsCheckIn(address(basedBits), owner);
        badgeBearPunkMinter.updateCheckInContract(newCheckIn);
        assertEq(address(badgeBearPunkMinter.checkInContract()), address(newCheckIn));
    }

    function testUpdateBadgeContract() public {
        assertEq(address(badgeBearPunkMinter.badgeContract()), address(badges));
        BBitsBadges newbadges = new BBitsBadges(owner);
        badgeBearPunkMinter.updateBadgeContract(newbadges);
        assertEq(address(badgeBearPunkMinter.badgeContract()), address(newbadges));
    }

    function testUpdateBadgeTokenId() public {
        assertEq(badgeBearPunkMinter.tokenId(), tokenId);
        badgeBearPunkMinter.updateBadgeTokenId(4);
        assertEq(badgeBearPunkMinter.tokenId(), 4);
    }
}