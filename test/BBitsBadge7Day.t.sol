// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/BBitsBadge7Day.sol";
import {IERC1155Mintable} from "../src/interfaces/IERC1155Mintable.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {ERC1155Mock} from "./mocks/ERC1155Mock.sol";
import {BBitsCheckInMock} from "./mocks/BBitsCheckInMock.sol";

contract BBitsBadge7DayTest is Test {

    BBitsBadge7Day public badgeMinter;
    IERC1155Mintable public collection;
    BBitsCheckInMock public checkin;

    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        collection = IERC1155Mintable(address(new ERC1155Mock()));
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
        badgeMinter.updateCheckInAddress(newAddress);
        assertEq(badgeMinter.bBitsCheckInAddress(), newAddress);
    }

    function testFailUpdateCheckInAddressByNonOwner() public {
        address newAddress = address(0x2);
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateCheckInAddress(newAddress);
    }

    function testUpdateBadgeCollectionAddressByOwner() public {
        address newAddress = address(0x3);
        badgeMinter.updateBadgeCollectionAddress(newAddress);
        assertEq(badgeMinter.erc1155Address(), newAddress);
    }

    function testFailUpdateBadgeCollectionAddressByNonOwner() public {
        address newAddress = address(0x3);
        vm.prank(user); // Acting as a non-owner
        badgeMinter.updateBadgeCollectionAddress(newAddress);
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
}
