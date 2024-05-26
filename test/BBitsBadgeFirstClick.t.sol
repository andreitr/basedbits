// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/BBitsBadge7Day.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {IBBitsBadges} from "../src/interfaces/IBBitsBadges.sol";
import {BBitsBadgesMock} from "./mocks/BBitsBadgesMock.sol";
import {BBitsCheckInMock} from "./mocks/BBitsCheckInMock.sol";
import {BBitsBadgeFirstClick} from "../src/BBitsBadgeFirstClick.sol";

contract BBitsBadgeFirstClickTest is Test {

    BBitsBadgeFirstClick public badgeMinter;
    IBBitsBadges public collection;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        address[] memory minters = new address[](1);
        minters[0] = user;

        collection = IBBitsBadges(address(new BBitsBadgesMock()));
        badgeMinter = new BBitsBadgeFirstClick(minters, address(collection), 2, owner);
    }

    function testMintAllowed() public {
        vm.prank(user);
        badgeMinter.mint();
        assertEq(collection.balanceOf(user, 2), 1);
    }

    function testFailMint() public {
        vm.prank(address(0x2));
        badgeMinter.mint();
    }

    function testCantMint() public {
        assertFalse(badgeMinter.canMint(address(0x2)));
    }

    function testMintOnlyOnce() public {
        vm.startPrank(user);
        badgeMinter.mint();
        assertFalse(badgeMinter.canMint(user));

        vm.expectRevert();
        badgeMinter.mint();
        vm.stopPrank();
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
        uint256 newTokenId = 3;
        badgeMinter.updateBadgeTokenId(newTokenId);
        assertEq(badgeMinter.tokenId(), newTokenId);
    }

    function testFailUpdateBadgeTokenIdByNonOwner() public {
        uint256 newTokenId = 3;
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateBadgeTokenId(newTokenId);
    }

    function testDeployWithEmptyMinters() public {
        address[] memory minters = new address[](0);
        BBitsBadgeFirstClick emptyMinterContract = new BBitsBadgeFirstClick(minters, address(collection), 2, owner);
        vm.prank(user);
        vm.expectRevert("Not allowed to mint");
        emptyMinterContract.mint();
    }

    function testAddMinter() public {
        address newMinter = address(0x4);
        vm.prank(owner);
        badgeMinter.addMinter(newMinter);
        assertTrue(badgeMinter.canMint(newMinter));
    }

    function testRemoveMinter() public {
        vm.prank(owner);
        badgeMinter.removeMinter(user);
        assertFalse(badgeMinter.canMint((user)));
    }
}
