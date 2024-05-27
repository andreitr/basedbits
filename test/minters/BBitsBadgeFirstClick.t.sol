// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsBadgeFirstClick} from "../../src/minters/BBitsBadgeFirstClick.sol";
import {BBitsTestUtils, console} from "../utils/BBitsTestUtils.sol";

contract BBitsBadgeFirstClickTest is BBitsTestUtils {

    function testMintAllowed() public {
        vm.prank(user0);
        badgeFirstClickMinter.mint();
        assertEq(badges.balanceOf(user0, 2), 1);
    }

    function testFailMint() public {
        vm.prank(user1);
        badgeFirstClickMinter.mint();
    }

    function testCantMint() public view {
        assertFalse(badgeFirstClickMinter.canMint(user1));
    }

    function testMintOnlyOnce() public {
        vm.startPrank(user0);
        badgeFirstClickMinter.mint();
        assertFalse(badgeFirstClickMinter.canMint(user0));

        vm.expectRevert();
        badgeFirstClickMinter.mint();
        vm.stopPrank();
    }

    function testUpdateBadgeCollectionAddressByOwner() public {
        address newAddress = address(0x3);
        badgeFirstClickMinter.updateBadgeContract(newAddress);
        assertEq(badgeFirstClickMinter.badgeContract(), newAddress);
    }

    function testFailUpdateBadgeCollectionAddressByNonOwner() public {
        address newAddress = address(0x3);
        vm.prank(user0); // Acting as a non-owner
        badgeFirstClickMinter.updateBadgeContract(newAddress);
    }

    function testUpdateBadgeTokenIdByOwner() public {
        uint256 newTokenId = 3;
        badgeFirstClickMinter.updateBadgeTokenId(newTokenId);
        assertEq(badgeFirstClickMinter.tokenId(), newTokenId);
    }

    function testFailUpdateBadgeTokenIdByNonOwner() public {
        uint256 newTokenId = 3;
        vm.prank(user0); // Acting as a non-owner
        badgeFirstClickMinter.updateBadgeTokenId(newTokenId);
    }

    function testDeployWithEmptyMinters() public {
        address[] memory minters = new address[](0);
        BBitsBadgeFirstClick emptyMinterContract = new BBitsBadgeFirstClick(minters, address(badges), 2, owner);
        vm.prank(user0);
        vm.expectRevert("Not allowed to mint");
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
