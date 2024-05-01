// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BBitsCheckIn.sol";

import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {BBitsCheckIn} from "../src/BBitsCheckIn.sol";

contract MockERC721 is IERC721 {
    mapping(address => uint256) public balances;
    mapping(uint256 => address) private _owners;

    function balanceOf(address owner) public view override returns (uint256) {
        return balances[owner];
    }

    function mint(address to, uint256 amount) public {
        balances[to] += amount;
        // Simple way to handle ownership for minted tokens
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(to, i)));
            _owners[tokenId] = to;
            emit Transfer(address(0), to, tokenId);
        }
    }

    function ownerOf(uint256 tokenId) public view override returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        require(to != address(0), "ERC721: transfer to the zero address");
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        balances[from] -= 1;
        balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
        if (to.code.length > 0) {
            require(IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) == IERC721Receiver.onERC721Received.selector, "ERC721: transfer to non ERC721Receiver implementer");
        }
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function approve(address to, uint256 tokenId) public override {}

    function getApproved(uint256 tokenId) public view override returns (address) {
        return address(0);
    }

    function setApprovalForAll(address operator, bool _approved) public override {}

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return false;
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC721).interfaceId || interfaceId == type(IERC721Receiver).interfaceId;
    }
}

contract BBitsCheckInTest is Test {
    BBitsCheckIn public bbCheckIn;
    MockERC721 public mockERC721;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this); // Test contract is the owner
        user = address(0x1);
        mockERC721 = new MockERC721();

        bbCheckIn = new BBitsCheckIn(address(mockERC721), owner);
    }

    function testInitialSettings() public {
        assertEq(bbCheckIn.collection(), address(mockERC721));
    }

//    function testCheckIn() public {
//
//        mockERC721.mint(user, 6);
//        vm.prank(user);
//
//        bbCheckIn.checkIn();
//
//        // Verify streak and check-in count
//        (, uint256 streak, uint256 checkInCount) = bbCheckIn.userStats(user);
//        assertEq(streak, 1);
//        assertEq(checkInCount, 1);
//    }


//    function testPauseContract() public {
//        // Pause the contract
//        bbCheckIn.pause();
//
//        // Attempt to check-in while paused
//        vm.prank(user);
//        bbCheckIn.checkIn();
//        assertTrue(bbCheckIn.paused());
//    }

    function testUnpauseContract() public {
        // Pause and then unpause the contract
        bbCheckIn.pause();
        bbCheckIn.unpause();

        assertFalse(bbCheckIn.paused());
    }

    function testBanUser() public {
        // Ban a user
        address bannedUser = address(0x2);
        bbCheckIn.ban(bannedUser);

        assertTrue(bbCheckIn.isBanned(bannedUser));
    }

    function testUnbanUser() public {
        // Ban and then unban a user
        address bannedUser = address(0x2);
        bbCheckIn.ban(bannedUser);
        bbCheckIn.unban(bannedUser);

        assertFalse(bbCheckIn.isBanned(bannedUser));
    }


    function testFailCheckInNotEnoughNFTs() public {
        vm.prank(user);
        bbCheckIn.checkIn();
    }

    function testFailCheckInBannedWallet() public {
        address bannedUser = address(0x2);
        mockERC721.mint(bannedUser, 2);
        bbCheckIn.ban(bannedUser); // Ban the user
        vm.prank(bannedUser); // Acting as the banned user
        bbCheckIn.checkIn();
    }

    function testBanAddress() public {
        address bannedUser = address(0x2);
        bbCheckIn.ban(bannedUser);
        assertTrue(bbCheckIn.isBanned(bannedUser));
    }

    function testIsBanned() public {
        address bannedUser = address(0x2);
        assertFalse(bbCheckIn.isBanned(bannedUser));
        bbCheckIn.ban(bannedUser);
        assertTrue(bbCheckIn.isBanned(bannedUser));
    }

    function testUnbanAddress() public {
        address bannedUser = address(0x2);
        bbCheckIn.ban(bannedUser); // Ban the user
        assertTrue(bbCheckIn.isBanned(bannedUser));

        bbCheckIn.unban(bannedUser); // Unban the user
        assertFalse(bbCheckIn.isBanned(bannedUser));
    }


    function testUpdateCollection() public {
        address newCollection = address(0x2);
        bbCheckIn.updateCollection(newCollection);
        assertEq(bbCheckIn.collection(), newCollection);
    }

    function testFailUpdateCollectionNotOwner() public {
        address newCollection = address(0x3);
        vm.prank(user); // Acting as a non-owner
        bbCheckIn.updateCollection(newCollection);
    }

    function testPause() public {
        bbCheckIn.pause();
        assertTrue(bbCheckIn.paused());
    }

    function testFailPauseNotOwner() public {
        vm.prank(user); // Acting as a non-owner
        bbCheckIn.pause();
    }

    function testUnpause() public {
        bbCheckIn.pause();
        bbCheckIn.unpause();
        assertFalse(bbCheckIn.paused());
    }

    function testFailUnpauseNotOwner() public {
        bbCheckIn.pause();
        vm.prank(user); // Acting as a non-owner
        bbCheckIn.unpause();
    }

    function testFailCheckInWhenPaused() public {
        mockERC721.mint(user, 6); // Mint 6 NFTs to user
        bbCheckIn.pause();
        vm.prank(user);
        bbCheckIn.checkIn();
    }

    function testOwnershipTransfer() public {
        bbCheckIn.transferOwnership(user); // Transfer ownership to user
        assertTrue(bbCheckIn.owner() == user);
    }
}