// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BBitsBadges.sol";

contract BBitsBadgesTest is Test {

    BBitsBadges private badges;
    address private owner;
    address private minter;
    address private user;

    function setUp() public {
        owner = address(this);
        minter = address(0x1);
        user = address(0x2);

        badges = new BBitsBadges(owner);
        badges.grantRole(badges.MINTER_ROLE(), minter);
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

    function testTokenURI() public view { // Marked as view
        assertEq(badges.uri(1), "https://basedbits.fun/api/badges/{id}");
    }

    function testContractMetadataURI() public view { // Marked as view
        assertEq(badges.contractURI(), "https://basedbits.fun/api/badges");
    }

    function testUpdateContractMetadataURI() public {
        vm.prank(owner);
        badges.updateContractURI("https://newuri.com/api/badges");
        assertEq(badges.contractURI(), "https://newuri.com/api/badges");
    }

    function testFailUpdateContractMetadataURIIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert("AccessControl: account is missing role");
        badges.updateContractURI("https://newuri.com/api/badges");
    }

    function testSetTokenURI() public {
        vm.prank(owner);
        badges.setURI('https://newuri.com/token/{id}.json');
        assertEq(badges.uri(1), "https://newuri.com/token/{id}.json");
    }

    function testFailMintIfNotMinter() public {
        vm.prank(user);
        vm.expectRevert("AccessControl: account is missing role");
        badges.mint(user, 1);
    }

    function testFailIfMinterRevoked() public {
        vm.prank(owner);
        badges.revokeRole(badges.MINTER_ROLE(), minter);
        vm.prank(minter);
        vm.expectRevert("AccessControl: account is missing role");
        badges.mint(user, 1);
    }
}
