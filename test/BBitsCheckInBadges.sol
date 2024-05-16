// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBitsCheckInBadges.sol";

contract BBitsCheckInBadgesTest is Test {

    BBitsCheckInBadges private badges;
    address private owner;
    address private minter;
    address private user;

    function setUp() public {
        owner = address(this);
        minter = address(0x1);
        user = address(0x2);

        badges = new BBitsCheckInBadges("https://api.example.com/metadata/");

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

    function testMintBatch() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        badges.mintBatch(user, ids, amounts, "");

        assertEq(badges.balanceOf(user, 1), 100);
        assertEq(badges.balanceOf(user, 2), 200);
    }

    function testFailMintBatchIfNotMinter() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(user);
        badges.mintBatch(user, ids, amounts, "");
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
