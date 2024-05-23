// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBitsBadges.sol";

contract BBitsCheckInBadgesTest is Test {

    BBitsBadges private badges;
    address private owner;
    address private minter;
    address private user;

    function setUp() public {
        owner = address(this);
        minter = address(0x1);
        user = address(0x2);

        badges = new BBitsBadges("https://basedbits.fun/api/badges/{id}.json", minter, owner);
    }

    function testMint() public {
        vm.prank(minter);
        badges.mint(user, 1);

        assertEq(badges.balanceOf(user, 1), 1);
    }

    function testSingleMint() public {
        vm.prank(minter);
        badges.mint(user, 55);
        assertEq(badges.balanceOf(user, 55), 1);
    }

    function testTokenURI() public {
        assertEq(badges.uri(1), "bas");

    }

    function testSetTokenURI() public {
        badges.setURI('new.com/');
        assertEq(badges.uri(1), "new.com/1");
    }

    function testFailMintIfNotMinter() public {
        vm.prank(user);
        badges.mint(user, 1);
    }

    function testFailIfMinterRevoked() public {
        badges.revokeRole(badges.MINTER_ROLE(), minter);
        badges.mint(user, 1);
    }
}
