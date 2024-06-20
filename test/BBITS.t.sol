// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils,
    BBITS,
    console
} from "./utils/BBitsTestUtils.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IBBITS} from "../src/interfaces/IBBITS.sol";

contract BBITSTest is BBitsTestUtils, IBBITS {
    function setUp() public override {
        uint256 baseFork = vm.createFork("https://1rpc.io/base");
        vm.selectFork(baseFork);

        owner = 0x1d671d1B191323A38490972D58354971E5c1cd2A;
        /// @dev Use this to access owner token Ids to allow for easy test updating
        ownerTokenIds = [159, 215, 432, 438, 6161];

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        bbits = new BBITS(basedBits, 1024);

        vm.prank(owner);
        basedBits.setApprovalForAll(address(bbits), true);
    }

    function testInit() public view {
        assertEq(bbits.name(), "Based Bits");
        assertEq(bbits.symbol(), "BBITS");
        assertEq(address(bbits.collection()), address(basedBits));
        assertEq(bbits.conversionRate(), 1024e18);
        assertEq(bbits.count(), 0);
    }

    /// NFTS -> TOKENS ///

    function testExchangeNFTsForTokensRevertConditions() public prank(owner) {
        uint256[] memory tokenIds = new uint256[](0);

        /// Exchange zero
        vm.expectRevert(DepositZero.selector);
        bbits.exchangeNFTsForTokens(tokenIds);

        /// Exchange non-owned
        tokenIds = new uint256[](1);
        tokenIds[0] = 8001;

        vm.expectRevert();
        bbits.exchangeNFTsForTokens(tokenIds);
    }

    function testExchangeNFTsForTokensSuccessConditions() public prank(owner) {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];

        assertEq(bbits.balanceOf(owner), 0);

        bbits.exchangeNFTsForTokens(tokenIds);

        assertEq(bbits.balanceOf(owner), 3072e18);
        assertEq(basedBits.balanceOf(address(bbits)), 3);
        assertEq(bbits.count(), 3);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[0]);
        assertEq(bbits.getTokenIdAtIndex(1), ownerTokenIds[1]);
        assertEq(bbits.getTokenIdAtIndex(2), ownerTokenIds[2]);

        vm.expectRevert(IndexOutOfBounds.selector);
        bbits.getTokenIdAtIndex(3);
    }

    /// TOKENS -> NFTS ///

    function testExchangeTokensForNFTsRevertConditions() public prank(owner) {
        /// Exchange zero
        vm.expectRevert(DepositZero.selector);
        bbits.exchangeTokensForNFTs(0);

        /// Partial redemption
        vm.expectRevert(PartialRedemptionDisallowed.selector);
        bbits.exchangeTokensForNFTs(1024e18 - 1);

        /// None owner of amount
        vm.expectRevert();
        bbits.exchangeTokensForNFTs(1024e18);
    }

    function testExchangeTokensForNFTsSuccessConditions() public prank(owner) {
        /// Set up
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        bbits.exchangeNFTsForTokens(tokenIds);

        assertEq(bbits.balanceOf(owner), 3072e18);
        assertEq(basedBits.balanceOf(address(bbits)), 3);
        assertEq(bbits.count(), 3);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[0]);
        assertEq(bbits.getTokenIdAtIndex(1), ownerTokenIds[1]);
        assertEq(bbits.getTokenIdAtIndex(2), ownerTokenIds[2]);

        /// Exchange for one NFT
        bbits.exchangeTokensForNFTs(1024e18);

        assertEq(bbits.balanceOf(owner), 2048e18);
        assertEq(basedBits.balanceOf(address(bbits)), 2);
        assertEq(bbits.count(), 2);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[2]);
        assertEq(bbits.getTokenIdAtIndex(1), ownerTokenIds[1]);
        assertEq(basedBits.ownerOf(ownerTokenIds[0]), owner);

        /// Exchange for the remaining two
        bbits.exchangeTokensForNFTs(2048e18);

        assertEq(bbits.balanceOf(owner), 0);
        assertEq(basedBits.balanceOf(address(bbits)), 0);
        assertEq(bbits.count(), 0);
        assertEq(basedBits.ownerOf(ownerTokenIds[0]), owner);
        assertEq(basedBits.ownerOf(ownerTokenIds[1]), owner);
        assertEq(basedBits.ownerOf(ownerTokenIds[2]), owner);
    }

    function testExchangeTokensForSpecificNFTsRevertConditions() public prank(owner) {
        /// Set up
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        bbits.exchangeNFTsForTokens(tokenIds);

        uint256[] memory indices;

        /// Exchange zero
        vm.expectRevert(DepositZero.selector);
        bbits.exchangeTokensForSpecificNFTs(0, indices);

        /// Partial redemption
        vm.expectRevert(PartialRedemptionDisallowed.selector);
        bbits.exchangeTokensForSpecificNFTs(1024e18 - 1, indices);

        /// Incorect array length
        vm.expectRevert(IndicesMustEqualNumberToBeExchanged.selector);
        bbits.exchangeTokensForSpecificNFTs(1024e18, indices);

        indices = new uint256[](4);

        /// None owner of amount
        vm.expectRevert();
        bbits.exchangeTokensForSpecificNFTs(4096e18, indices);

        /// Index out of bounds
        indices = new uint256[](2);
        indices[0] = 7;
        vm.expectRevert(IndexOutOfBounds.selector);
        bbits.exchangeTokensForSpecificNFTs(2048e18, indices);

        /// Indices not monotonically decreasing
        indices[0] = 0;
        indices[1] = 1;
        vm.expectRevert(IndicesMustBeMonotonicallyDecreasing.selector);
        bbits.exchangeTokensForSpecificNFTs(2048e18, indices);
    }

    function testExchangeTokensForSpecificNFTsSuccessConditions() public prank(owner) {
        uint256[] memory tokenIds = new uint256[](5);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        tokenIds[3] = ownerTokenIds[3];
        tokenIds[4] = ownerTokenIds[4];
        bbits.exchangeNFTsForTokens(tokenIds);
        uint256[] memory indices;

        assertEq(bbits.balanceOf(owner), 5120e18);
        assertEq(basedBits.balanceOf(address(bbits)), 5);
        assertEq(bbits.count(), 5);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[0]);
        assertEq(bbits.getTokenIdAtIndex(1), ownerTokenIds[1]);
        assertEq(bbits.getTokenIdAtIndex(2), ownerTokenIds[2]);
        assertEq(bbits.getTokenIdAtIndex(3), ownerTokenIds[3]);
        assertEq(bbits.getTokenIdAtIndex(4), ownerTokenIds[4]);

        /// Exchange for one NFT
        indices = new uint256[](1);
        indices[0] = 1;

        bbits.exchangeTokensForSpecificNFTs(1024e18, indices);

        assertEq(bbits.balanceOf(owner), 4096e18);
        assertEq(basedBits.balanceOf(address(bbits)), 4);
        assertEq(bbits.count(), 4);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[0]);
        assertEq(bbits.getTokenIdAtIndex(1), ownerTokenIds[4]);
        assertEq(bbits.getTokenIdAtIndex(2), ownerTokenIds[2]);
        assertEq(bbits.getTokenIdAtIndex(3), ownerTokenIds[3]);
        assertEq(basedBits.ownerOf(ownerTokenIds[1]), owner);

        /// Exchange for three NFTS
        indices = new uint256[](3);
        indices[0] = 3;
        indices[1] = 2;
        indices[2] = 0;

        bbits.exchangeTokensForSpecificNFTs(3072e18, indices);

        assertEq(bbits.balanceOf(owner), 1024e18);
        assertEq(basedBits.balanceOf(address(bbits)), 1);
        assertEq(bbits.count(), 1);
        assertEq(bbits.getTokenIdAtIndex(0), ownerTokenIds[4]);
        assertEq(basedBits.ownerOf(ownerTokenIds[0]), owner);
        assertEq(basedBits.ownerOf(ownerTokenIds[1]), owner);
        assertEq(basedBits.ownerOf(ownerTokenIds[2]), owner);
        assertEq(basedBits.ownerOf(ownerTokenIds[3]), owner);
    }
}