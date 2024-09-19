// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsSocialRewards, BBITS, IERC20, console} from "@test/utils/BBitsTestUtils.sol";
import {IBBitsSocialRewards} from "@src/interfaces/IBBitsSocialRewards.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract BBitsSocialRewardsTest -vvv --gas-report
contract BBitsSocialRewardsTest is BBitsTestUtils, IBBitsSocialRewards {
    string public link = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";

    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);
        vm.deal(user0, 1e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        bbits = BBITS(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        socialRewards = new BBitsSocialRewards(owner, bbits);

        vm.startPrank(owner);
        /// Owner gets BBITS tokens
        basedBits.setApprovalForAll(address(bbits), true);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        bbits.exchangeNFTsForTokens(tokenIds);

        bbits.approve(address(socialRewards), ~uint256(0));
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(socialRewards.owner(), owner);
        assertEq(address(socialRewards.BBITS()), address(bbits));
        assertEq(socialRewards.count(), 0);
        assertEq(socialRewards.duration(), 7 days);
        assertEq(socialRewards.totalRewardsPerRound(), 1024e18);
        assertEq(socialRewards.rewardPercentage(), 9000);
        assert(socialRewards.status() == RewardsStatus.PendingRound);
    }

    /// SUBMIT POST ///

    function testSubmitPostRevertConditions() public {
        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        socialRewards.submitPost(link);

        /// Round expired
        vm.startPrank(owner);
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();
        vm.stopPrank();
        vm.warp(block.timestamp + 100 days);

        vm.expectRevert(RoundExpired.selector);
        socialRewards.submitPost(link);
    }

    function testSubmitPostSuccessConditions() public {
        vm.startPrank(owner);
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();
        vm.stopPrank();

        (,,,, uint256 entriesCount,) = socialRewards.round(1);
        assertEq(entriesCount, 0);

        vm.expectRevert(IndexOutOfBounds.selector);
        socialRewards.getEntryInfoForId(1, 0);

        vm.startPrank(user0);
        vm.expectEmit(true, true, true, true);
        emit NewEntry(1, 1, user0, link);
        socialRewards.submitPost(link);
        vm.stopPrank();

        (,,,, entriesCount,) = socialRewards.round(1);
        assertEq(entriesCount, 1);

        Entry memory entry = socialRewards.getEntryInfoForId(1, 0);
        assertEq(entry.approved, false);
        assertEq(entry.post, link);
        assertEq(entry.user, user0);
        assertEq(entry.timestamp, block.timestamp);
    }

    /// DEPOSIT BBITS ///

    function testDepositBBITSRevertConditions() public {
        /// Amount zero
        vm.startPrank(owner);
        vm.expectRevert(AmountZero.selector);
        socialRewards.depositBBITS(0);
        vm.stopPrank();
    }

    function testDepositBBITSSuccessConditions() public {
        assertEq(bbits.balanceOf(address(socialRewards)), 0);
        vm.startPrank(owner);
        socialRewards.depositBBITS(1);
        vm.stopPrank();
        assertEq(bbits.balanceOf(address(socialRewards)), 1);
    }

    /// APPROVE POSTS ///

    function testApprovePostsRevertConditions() public prank(owner) {
        uint256[] memory entryIds = new uint256[](1);

        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        socialRewards.approvePosts(entryIds);

        /// Index out of bounds
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        vm.expectRevert(IndexOutOfBounds.selector);
        socialRewards.approvePosts(entryIds);

        socialRewards.submitPost(link);
        entryIds[0] = 1;

        vm.expectRevert(IndexOutOfBounds.selector);
        socialRewards.approvePosts(entryIds);
    }

    function testApprovePostsSuccessConditions() public prank(owner) {
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        socialRewards.submitPost(link);

        Entry memory entry = socialRewards.getEntryInfoForId(1, 0);
        assertEq(entry.approved, false);
        assertEq(entry.post, link);
        assertEq(entry.user, owner);
        assertEq(entry.timestamp, block.timestamp);

        uint256[] memory entryIds = new uint256[](1);
        socialRewards.approvePosts(entryIds);

        entry = socialRewards.getEntryInfoForId(1, 0);
        assertEq(entry.approved, true);

        socialRewards.submitPost(link);
        socialRewards.submitPost(link);

        entryIds = new uint256[](2);
        entryIds[0] = 1;
        entryIds[1] = 2;
        socialRewards.approvePosts(entryIds);

        entry = socialRewards.getEntryInfoForId(1, 1);
        assertEq(entry.approved, true);

        entry = socialRewards.getEntryInfoForId(1, 2);
        assertEq(entry.approved, true);
    }

    /// SETTLE CURRENT ROUND ///
    
    /*
    (
        uint256 startedAt,
        uint256 settledAt,
        uint256 userReward,
        uint256 adminReward,
        uint256 entriesCount,
        uint256 rewardedCount
    ) = socialRewards.round(1);
    */

    function testSettleCurrentRoundRevertConditions() public prank(owner) {
        /// Wrong status


        /// Round active
    }

    /// START NEW ROUND ///

    /*
    function testGas() public prank(user0) {
        for (uint256 i; i < 1000; i++) {
            socialRewards.submitPost(link);
        }
        
        vm.warp(block.timestamp + 100 days);

        vm.stopPrank();
        vm.startPrank(owner);

        uint256[] memory entryIds = new uint256[](100);
        for (uint256 j; j < 100; j++) {
            entryIds[j] = j;
        }

        socialRewards.approvePosts(entryIds);
        socialRewards.settleCurrentRound();
    }
    */
}
