// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC1155MetadataURI, IERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {IAccessControl} from "@openzeppelin/access/AccessControl.sol";
import {BBitsTestUtils, console} from "@test/utils/BBitsTestUtils.sol";

/// @dev forge test --match-contract BBitsBadgesTest -vvv
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

    function testTokenURI() public view {
        // Marked as view
        assertEq(badges.uri(1), "https://basedbits.fun/api/badges/{id}");
    }

    function testContractMetadataURI() public view {
        // Marked as view
        assertEq(badges.contractURI(), "https://basedbits.fun/api/badges");
    }

    function testUpdateContractMetadataURI() public {
        vm.prank(owner);
        badges.updateContractURI("https://newuri.com/api/badges");
        assertEq(badges.contractURI(), "https://newuri.com/api/badges");
    }

    function testUpdateContractMetadataURIIfNotOwner() public {
        vm.prank(user0);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user0, bytes32(0))
        );
        badges.updateContractURI("https://newuri.com/api/badges");
    }

    function testSetTokenURI() public {
        vm.prank(owner);
        badges.setURI("https://newuri.com/token/{id}.json");
        assertEq(badges.uri(1), "https://newuri.com/token/{id}.json");
    }

    function testMintIfNotMinter() public {
        bytes32 minter_role = badges.MINTER_ROLE();
        vm.prank(user0);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user0, minter_role)
        );
        badges.mint(user0, 1);
    }

    function testIfMinterRevoked() public {
        bytes32 minter_role = badges.MINTER_ROLE();
        vm.prank(owner);
        badges.revokeRole(minter_role, minter);
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, minter_role)
        );
        badges.mint(user0, 1);
    }

    function testSupportsInterface() public view {
        assertEq(badges.supportsInterface(type(IERC1155).interfaceId), true);
        assertEq(badges.supportsInterface(type(IERC1155MetadataURI).interfaceId), true);
        assertEq(badges.supportsInterface(type(IAccessControl).interfaceId), true);
    }
}
