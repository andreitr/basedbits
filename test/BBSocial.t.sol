// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BBSocial} from "../src/BBSocial.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BBSocialTest is Test {
    BBSocial public bbsocial;
    ERC721 public nft;

    function setUp() public {
        nft = new ERC721("TestNFT", "TNFT");
        bbsocial = new BBSocial(address(nft), 10);
    }

    function testPostMessageWithEnoughNFTs() public {
        nft.mint(address(this), 1);
        nft.approve(address(bbsocial), 1);
        bbsocial.postMessage("Hello, world!");
    }

    function testPostMessageWithoutEnoughNFTs() public {
        try bbsocial.postMessage("Hello, world!") {
            fail("Expected postMessage to revert when sender does not have enough NFTs");
        } catch Error(string memory reason) {
            assertEq(reason, "Sender does not have enough NFTs to post");
        }
    }

    function testUpdateThreshold() public {
        bbsocial.updateThreshold(20);
        assertEq(bbsocial.postThreshold(), 20);
    }

    function testUpdateCollection() public {
        ERC721 newNFT = new ERC721("TestNFT2", "TNFT2");
        bbsocial.updateCollection(address(newNFT));
        assertEq(address(bbsocial.collection()), address(newNFT));
    }
}