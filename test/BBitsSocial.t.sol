// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BBitsSocial.sol";

import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

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

contract BBitsSocialTest is Test {
    BBitsSocial public bbSocial;
    MockERC721 public mockERC721;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this); // Test contract is the owner
        user = address(0x1);
        mockERC721 = new MockERC721();

        bbSocial = new BBitsSocial(5, address(mockERC721), owner);
    }

    function testInitialSettings() public {
        assertEq(bbSocial.threshold(), 5);
        assertEq(bbSocial.collection(), address(mockERC721));
    }

    function testPostMessage() public {
        mockERC721.mint(user, 6); // Mint 6 NFTs to user
        vm.prank(user);
        bbSocial.postMessage("Hello World!");
        assertEq(bbSocial.walletPosts(user), 1);
        assertEq(bbSocial.walletPoints(user), 6);
    }

    function testPostMultipleMessages() public {
        mockERC721.mint(user, 7); // Mint 7 NFTs to user
        vm.prank(user);

        bbSocial.postMessage("Message 1");
        assertEq(bbSocial.walletPosts(user), 1);
        assertEq(bbSocial.walletPoints(user), 7);

        vm.prank(user);
        bbSocial.postMessage("Message 2");
        assertEq(bbSocial.walletPosts(user), 2);
        assertEq(bbSocial.walletPoints(user), 14);
    }

    function testFailPostMessageNotEnoughNFTs() public {
        mockERC721.mint(user, 4); // Mint 4 NFTs to user, not enough to meet the threshold
        vm.prank(user);
        bbSocial.postMessage("This should fail");
    }

    function testFailPostMessageTooManyCharacters() public {
        mockERC721.mint(user, 6); // Mint 4 NFTs to user, not enough to meet the threshold
        vm.prank(user);
        bbSocial.postMessage("Today, I stumbled upon an old journal. Reading my past thoughts feels like meeting an old friend. Memories flood back, reminding me of who I am.");
    }


    function testGetWalletPosts() public {
        mockERC721.mint(user, 6); // Mint 6 NFTs to user
        vm.prank(user);
        bbSocial.postMessage("Hello World!");
        assertEq(bbSocial.getWalletPosts(user), 1);
    }

    function testGetWalletPoints() public {
        mockERC721.mint(user, 6); // Mint 6 NFTs to user
        vm.prank(user);
        bbSocial.postMessage("Hello World!");
        assertEq(bbSocial.getWalletPoints(user), 6);
    }

    function testFailPostMessageBannedWallet() public {
        address bannedUser = address(0x2);
        mockERC721.mint(bannedUser, 6); // Mint 6 NFTs to bannedUser
        bbSocial.banAddress(bannedUser); // Ban the user
        vm.prank(bannedUser); // Acting as the banned user
        bbSocial.postMessage("This should fail because the wallet is banned");
    }

    function testBanAddress() public {
        address bannedUser = address(0x2);
        bbSocial.banAddress(bannedUser);
        assertTrue(bbSocial.isBanned(bannedUser));
    }

    function testIsBanned() public {
        address bannedUser = address(0x2);
        assertFalse(bbSocial.isBanned(bannedUser));
        bbSocial.banAddress(bannedUser);
        assertTrue(bbSocial.isBanned(bannedUser));
    }

    function testUnbanAddress() public {
        address bannedUser = address(0x2);
        bbSocial.banAddress(bannedUser); // Ban the user
        assertTrue(bbSocial.isBanned(bannedUser));

        bbSocial.unbanAddress(bannedUser); // Unban the user
        assertFalse(bbSocial.isBanned(bannedUser));
    }

    function testUpdateThreshold() public {
        bbSocial.updateThreshold(10);
        assertEq(bbSocial.threshold(), 10);
    }

    function testEdgeCaseThreshold() public {
        bbSocial.updateThreshold(type(uint16).max); // Set threshold to maximum value
        assertEq(bbSocial.threshold(), type(uint16).max);

        bbSocial.updateThreshold(0); // Set threshold to zero
        assertEq(bbSocial.threshold(), 0);
    }

    function testFailUpdateThresholdNotOwner() public {
        vm.prank(user); // Acting as a non-owner
        bbSocial.updateThreshold(10);
    }

    function testUpdateCollection() public {
        address newCollection = address(0x2);
        bbSocial.updateCollection(newCollection);
        assertEq(bbSocial.collection(), newCollection);
    }

    function testFailUpdateCollectionNotOwner() public {
        address newCollection = address(0x3);
        vm.prank(user); // Acting as a non-owner
        bbSocial.updateCollection(newCollection);
    }

    function testPause() public {
        bbSocial.pause();
        assertTrue(bbSocial.paused());
    }

    function testFailPauseNotOwner() public {
        vm.prank(user); // Acting as a non-owner
        bbSocial.pause();
    }

    function testUnpause() public {
        bbSocial.pause();
        bbSocial.unpause();
        assertFalse(bbSocial.paused());
    }

    function testFailUnpauseNotOwner() public {
        bbSocial.pause();
        vm.prank(user); // Acting as a non-owner
        bbSocial.unpause();
    }

    function testFailPostMessageWhenPaused() public {
        mockERC721.mint(user, 6); // Mint 6 NFTs to user
        bbSocial.pause();
        vm.prank(user);
        bbSocial.postMessage("This should fail");
    }

    function testOwnershipTransfer() public {
        bbSocial.transferOwnership(user); // Transfer ownership to user
        assertTrue(bbSocial.owner() == user);
    }
}