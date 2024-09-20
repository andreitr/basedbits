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

    function testSettleCurrentRoundRevertConditions() public prank(owner) {
        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        socialRewards.settleCurrentRound();

        /// Round active
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        vm.expectRevert(RoundActive.selector);
        socialRewards.settleCurrentRound();
    }

    function testSettleCurrentRoundSuccessConditionsWithoutApprovals() public prank(owner) {
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        uint256 startTime = block.timestamp;

        (
            uint256 startedAt,
            uint256 settledAt,
            uint256 userReward,
            uint256 adminReward,
            uint256 entriesCount,
            uint256 rewardedCount
        ) = socialRewards.round(1);
        assertEq(startedAt, startTime);
        assertEq(settledAt, 0);
        assertEq(userReward, 0);
        assertEq(adminReward, 0);
        assertEq(entriesCount, 0);
        assertEq(rewardedCount, 0);
        assert(socialRewards.status() == RewardsStatus.InRound);
        assertEq(bbits.balanceOf(address(socialRewards)), 2048e18);

        vm.warp(block.timestamp + 100 days);

        vm.expectEmit(true, true, true, true);
        emit End(1, 0, 0);
        socialRewards.settleCurrentRound();

        (startedAt, settledAt, userReward, adminReward, entriesCount, rewardedCount) = socialRewards.round(1);
        assertEq(startedAt, startTime);
        assertEq(settledAt, block.timestamp);
        assertEq(userReward, 0);
        assertEq(adminReward, 0);
        assertEq(entriesCount, 0);
        assertEq(rewardedCount, 0);
        assert(socialRewards.status() == RewardsStatus.PendingRound);
        assertEq(bbits.balanceOf(address(socialRewards)), 2048e18);
    }

    function testSettleCurrentRoundSuccessConditionsWithApprovals() public prank(owner) {
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        uint256 startTime = block.timestamp;

        vm.stopPrank();
        vm.startPrank(user0);

        (uint256 startedAt, uint256 settledAt, uint256 userReward, uint256 adminReward,, uint256 rewardedCount) =
            socialRewards.round(1);
        assertEq(startedAt, startTime);
        assertEq(settledAt, 0);
        assertEq(userReward, 0);
        assertEq(adminReward, 0);
        assertEq(rewardedCount, 0);
        assert(socialRewards.status() == RewardsStatus.InRound);
        assertEq(bbits.balanceOf(address(socialRewards)), 2048e18);

        socialRewards.submitPost(link);

        vm.stopPrank();
        vm.startPrank(owner);

        vm.warp(block.timestamp + 100 days);

        uint256[] memory entryIds = new uint256[](1);
        socialRewards.approvePosts(entryIds);

        uint256 predictedUserRewards = ((1024e18 * 9000) / 10_000) / 1;
        uint256 predictedAdminRewards = 1024e18 - ((1024e18 * 9000) / 10_000);

        uint256 user0BalanceBefore = bbits.balanceOf(user0);
        uint256 ownerBalanceBefore = bbits.balanceOf(owner);

        vm.expectEmit(true, true, true, true);
        emit End(1, 1, predictedUserRewards);
        socialRewards.settleCurrentRound();

        (startedAt, settledAt, userReward, adminReward,, rewardedCount) = socialRewards.round(1);
        assertEq(startedAt, startTime);
        assertEq(settledAt, block.timestamp);
        assertEq(userReward, predictedUserRewards);
        assertEq(adminReward, predictedAdminRewards);
        assertEq(rewardedCount, 1);
        assert(socialRewards.status() == RewardsStatus.PendingRound);
        assertEq(bbits.balanceOf(address(socialRewards)), 1024e18);
        assertEq(bbits.balanceOf(user0), user0BalanceBefore + predictedUserRewards);
        assertEq(bbits.balanceOf(owner), ownerBalanceBefore + predictedAdminRewards);
    }

    /// START NEW ROUND ///

    function testStartNextRoundRevertConditions() public prank(owner) {
        /// Insufficient rewards
        vm.expectRevert(InsufficientRewards.selector);
        socialRewards.startNextRound();

        /// Wrong status
        socialRewards.depositBBITS(2048e18);
        socialRewards.startNextRound();

        vm.expectRevert(WrongStatus.selector);
        socialRewards.startNextRound();
    }

    /// OWNER ///

    function testSetPaused() public prank(owner) {
        assertEq(socialRewards.paused(), false);

        socialRewards.setPaused(true);
        assertEq(socialRewards.paused(), true);

        socialRewards.setPaused(false);
        assertEq(socialRewards.paused(), false);
    }

    function testSetDuration() public prank(owner) {
        assertEq(socialRewards.duration(), 7 days);

        socialRewards.setDuration(100 days);
        assertEq(socialRewards.duration(), 100 days);
    }

    function testSetTotalRewardsPerRound() public prank(owner) {
        assertEq(socialRewards.totalRewardsPerRound(), 1024e18);

        socialRewards.setTotalRewardsPerRound(2048e18);
        assertEq(socialRewards.totalRewardsPerRound(), 2048e18);
    }

    function testSetRewardPercentage() public prank(owner) {
        assertEq(socialRewards.rewardPercentage(), 9000);

        socialRewards.setRewardPercentage(1000);
        assertEq(socialRewards.rewardPercentage(), 1000);

        vm.expectRevert(InvalidPercentage.selector);
        socialRewards.setRewardPercentage(10001);
    }
}
