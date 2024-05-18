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

        badges = new BBitsBadges("https://api.example.com/metadata/");

        badges.grantRole(badges.MINTER_ROLE(), minter);
    }

    function testMint() public {
        vm.prank(minter);
        badges.mint(user, 1, 100, "");

        assertEq(badges.balanceOf(user, 1), 100);
    }

    function testBalanceOf() public {
        vm.prank(minter);
        badges.mint(user, 1, 100, "");
        assertEq(badges.balanceOf(user, 1), 100);
    }

    function testSetTokenURI() public {
        vm.prank(owner);
        badges.setTokenURI(1, "https://api.example.com/metadata/1");
        assertEq(badges.uri(1), "https://api.example.com/metadata/1");
    }

    function testFailSetTokenURIIfNotAdmin() public {
        vm.prank(user);
        badges.setTokenURI(1, "https://api.example.com/metadata/1");
    }

    function testFailMintIfNotMinter() public {
        vm.prank(user);
        badges.mint(user, 1, 100, "");
    }
}
