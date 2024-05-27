// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    console,
    BBitsCheckIn,
    BBitsBadges,
    BBitsBadgeFirstClick
} from "../utils/BBitsTestUtils.sol";

contract BBitsBadgeFirstClickTest is BBitsTestUtils {

    uint256 constant tokenId = 0x0000000000000000000000000000000000000000000000000000000000000002;

    function testInit() public {
        address[] memory minters = new address[](1);
        minters[0] = user0;
        badgeFirstClickMinter = new BBitsBadgeFirstClick(minters, badges, tokenId, owner);
        assertEq(address(badgeFirstClickMinter.badgeContract()), address(badges));
        assertEq(badgeFirstClickMinter.tokenId(), tokenId);
        assertEq(badgeFirstClickMinter.minter(user0), true);
    }

    function testMintSuccess() public {
        assertEq(badges.balanceOf(user0, tokenId), 0);
        assertEq(badgeFirstClickMinter.minted(user0), false);
        vm.prank(user0);
        badgeFirstClickMinter.mint();
        assertEq(badges.balanceOf(user0, tokenId), 1);
        assertEq(badgeFirstClickMinter.minted(user0), true);
    }

    function testSecondMintFailure() public {
        vm.startPrank(user0);
        badgeFirstClickMinter.mint();
        vm.expectRevert("User is not eligible to mint");
        badgeFirstClickMinter.mint();
    }

    function testCanMint() public {
        // Can mint
        assertEq(badgeFirstClickMinter.canMint(user0), true);

        // Already minted
        vm.prank(user0);
        badgeFirstClickMinter.mint();
        assertEq(badgeFirstClickMinter.canMint(user0), false);

        // Not a minter
        assertEq(badgeFirstClickMinter.canMint(user1), false);
    }

    function testUpdateBadgeCollectionAddressByOwner() public {
        assertEq(address(badgeFirstClickMinter.badgeContract()), address(badges));
        BBitsBadges newbadges = new BBitsBadges(owner);
        badgeFirstClickMinter.updateBadgeContract(newbadges);
        assertEq(address(badgeFirstClickMinter.badgeContract()), address(newbadges));
    }

    function testUpdateBadgeCollectionAddressByNonOwner() public {
        assertEq(address(badgeFirstClickMinter.badgeContract()), address(badges));
        BBitsBadges newbadges = new BBitsBadges(owner);
        vm.startPrank(user0); // Acting as a non-owner
        vm.expectRevert();
        badgeFirstClickMinter.updateBadgeContract(newbadges);
        vm.stopPrank();
    }

    function testUpdateBadgeTokenId() public {
        uint256 newTokenId = 3;
        badgeFirstClickMinter.updateBadgeTokenId(newTokenId);
        assertEq(badgeFirstClickMinter.tokenId(), newTokenId);
        vm.startPrank(user0); // Acting as a non-owner
        vm.expectRevert();
        badgeFirstClickMinter.updateBadgeTokenId(newTokenId);
        vm.stopPrank();
    }

    function testDeployWithEmptyMinters() public {
        address[] memory minters = new address[](0);
        BBitsBadgeFirstClick emptyMinterContract = new BBitsBadgeFirstClick(minters, badges, 2, owner);
        vm.prank(user0);
        vm.expectRevert("User is not eligible to mint");
        emptyMinterContract.mint();
    }

    function testAddMinter() public {
        address newMinter = address(0x4);
        vm.prank(owner);
        badgeFirstClickMinter.addMinter(newMinter);
        assertTrue(badgeFirstClickMinter.canMint(newMinter));
    }

    function testRemoveMinter() public {
        vm.prank(owner);
        badgeFirstClickMinter.removeMinter(user0);
        assertFalse(badgeFirstClickMinter.canMint(user0));
    }
}
