// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC1155MetadataURI, IERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {BBitsTestUtils, console} from "./utils/BBitsTestUtils.sol";

contract BBitsBadgesTest is BBitsTestUtils {

    address public minter;

    function setUp() public override {
        super.setUp();

        minter = address(0x3);
        badges.grantRole(badges.MINTER_ROLE(), minter);
    }

    function testMint() public {
        vm.prank(minter);
        badges.mint(user0, 1);

        assertEq(badges.balanceOf(user0, 1), 1);
    }

    function testSingleMint() public {
        vm.prank(minter);
        badges.mint(user0, 55);
        assertEq(badges.balanceOf(user0, 55), 1);
    }

    function testTokenURI() public view { // Marked as view
        assertEq(badges.uri(1), "https://basedbits.fun/api/badges/{id}");
    }

    function testContractMetadataURI() public view { // Marked as view
        assertEq(badges.contractURI(), "https://basedbits.fun/api/badges");
    }

    function testUpdateContractMetadataURI() public {
        vm.startPrank(owner);
        badges.updateContractURI("https://newuri.com/api/badges");
        assertEq(badges.contractURI(), "https://newuri.com/api/badges");
        vm.stopPrank();
    }

    function testUpdateContractMetadataURIIfNotOwner() public {
        vm.startPrank(user0);
        vm.expectRevert();
        badges.updateContractURI("https://newuri.com/api/badges");
        vm.stopPrank();
    }

    function testSetTokenURI() public {
        vm.startPrank(owner);
        badges.setURI('https://newuri.com/token/{id}.json');
        assertEq(badges.uri(1), "https://newuri.com/token/{id}.json");
        vm.stopPrank();
    }

    function testMintIfNotMinter() public {
        vm.startPrank(user0);
        vm.expectRevert();
        badges.mint(user0, 1);
        vm.stopPrank();
    }

    function testIfMinterRevoked() public {
        vm.prank(owner);
        badges.revokeRole(badges.MINTER_ROLE(), minter);
        vm.startPrank(minter);
        vm.expectRevert();
        badges.mint(user0, 1);
        vm.stopPrank();
    }

    function testSupportsInterface() public view {
        assertEq(badges.supportsInterface(type(IERC1155).interfaceId), true);
        assertEq(badges.supportsInterface(type(IERC1155MetadataURI).interfaceId), true);
        assertEq(badges.supportsInterface(type(IAccessControl).interfaceId), true);
    }
}
