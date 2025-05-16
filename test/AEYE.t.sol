// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {AEYE} from "../src/AEYE.sol";
import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";

contract MockBurner {
    function burn(uint256 _minAmountBurned) external payable {}
}

contract AEYETest is Test {
    AEYE public aeye;
    address public owner;
    address public artist;
    address public user1;
    address public user2;
    address public user3;
    MockBurner public burner;

    event TokenCreated(uint256 indexed tokenId, string metadata);
    event Start(uint256 indexed tokenId);
    event CommunityRewardsClaimed(
        uint256 indexed tokenId,
        address indexed user,
        uint256 amount
    );
    event PercentagesUpdated(
        uint256 burnPercentage,
        uint256 artistPercentage,
        uint256 communityPercentage
    );

    function setUp() public {
        owner = makeAddr("owner");
        artist = makeAddr("artist");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        burner = new MockBurner();

        vm.startPrank(owner);
        aeye = new AEYE(owner, artist, address(burner));
        vm.stopPrank();
    }

    function test_InitialState() public {
        assertEq(aeye.owner(), owner);
        assertEq(aeye.artist(), artist);
        assertEq(address(aeye.burner()), address(burner));
        assertEq(aeye.mintPrice(), 0.0008 ether);
        assertEq(aeye.burnPercentage(), 2000);
        assertEq(aeye.artistPercentage(), 3000);
        assertEq(aeye.communityPercentage(), 5000);
        assertTrue(aeye.paused());
    }

    function test_CreateToken() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        vm.stopPrank();

        vm.startPrank(owner);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        assertEq(aeye.currentMint(), 1);
        assertEq(aeye.uri(1), "test-metadata");
    }

    function test_Mint() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        assertEq(aeye.balanceOf(user1, 1), 1);
        assertTrue(aeye.hasMinted(1, user1));
        assertEq(aeye.mintingStreak(user1), 1);
    }

    function test_MintStreak() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        assertEq(aeye.mintingStreak(user1), 2);
    }

    function test_RewardDistribution() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Mint with user2
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check rewards
        assertTrue(aeye.unclaimedRewards(user1) > 0);
        assertTrue(aeye.unclaimedRewards(user2) > 0);
    }

    function test_ClaimRewards() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        uint256 initialBalance = user1.balance;
        uint256 rewards = aeye.unclaimedRewards(user1);

        vm.startPrank(user1);
        aeye.claimRewards();
        vm.stopPrank();

        assertEq(user1.balance, initialBalance + rewards);
        assertEq(aeye.unclaimedRewards(user1), 0);
    }

    function test_SetPercentages() public {
        vm.startPrank(owner);
        aeye.setPercentages(3000, 4000, 3000);
        vm.stopPrank();

        assertEq(aeye.burnPercentage(), 3000);
        assertEq(aeye.artistPercentage(), 4000);
        assertEq(aeye.communityPercentage(), 3000);
    }

    function test_UpdateTokenMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Verify token exists and has metadata
        assertTrue(aeye.hasMetadata(1), "Token should have metadata set");

        // Update metadata
        vm.startPrank(owner);
        aeye.updateTokenMetadata(1, "new-metadata");
        vm.stopPrank();

        assertEq(aeye.uri(1), "new-metadata");
    }

    function test_RevertWhen_MintWithoutMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        vm.expectRevert(AEYE.MetadataNotSet.selector);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();
    }

    function test_RevertWhen_MintInsufficientPayment() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        vm.expectRevert(AEYE.MustPayMintPrice.selector);
        aeye.mint{value: 0.0004 ether}();
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerSetPercentages() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        aeye.setPercentages(3000, 4000, 3000);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerUpdateMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1));
        aeye.updateTokenMetadata(0, "new-metadata");
        vm.stopPrank();
    }

    function test_RewardAccrualWithStreaks() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // User1 mints with a streak of 1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // User2 mints with a streak of 2
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // User2 mints again to increase streak
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create another token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata3");
        vm.stopPrank();

        // Check rewards - user2 should have more rewards due to higher streak
        uint256 user1Rewards = aeye.unclaimedRewards(user1);
        uint256 user2Rewards = aeye.unclaimedRewards(user2);
        assertTrue(user2Rewards > user1Rewards);
    }

    function test_RewardAccrualWithMultipleMinters() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Multiple users mint
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;

        for (uint i = 0; i < users.length; i++) {
            vm.deal(users[i], 1 ether);
            vm.startPrank(users[i]);
            aeye.mint{value: 0.0008 ether}();
            vm.stopPrank();
        }

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check that all users received rewards
        for (uint i = 0; i < users.length; i++) {
            assertTrue(aeye.unclaimedRewards(users[i]) > 0);
        }
    }

    function test_RewardAccrualWithDifferentPercentages() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Change percentages to give more to community
        vm.startPrank(owner);
        aeye.setPercentages(1000, 2000, 7000); // 10% burn, 20% artist, 70% community
        vm.stopPrank();

        // Mint with user2
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check rewards - user2 should have more rewards due to higher community percentage
        uint256 user1Rewards = aeye.unclaimedRewards(user1);
        uint256 user2Rewards = aeye.unclaimedRewards(user2);
        assertTrue(
            user2Rewards >= user1Rewards,
            "User2 should have at least as many rewards as user1"
        );
    }

    function test_RewardAccrualWithNoMinters() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Create new token without any minters
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check that no rewards were distributed
        assertEq(aeye.unclaimedRewards(user1), 0);
        assertEq(aeye.unclaimedRewards(user2), 0);
        assertEq(aeye.unclaimedRewards(user3), 0);
    }

    function test_WeightCalculation() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Test weight calculation for different streak levels
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Weight should be 11 (10 + 1) for streak of 1
        assertEq(aeye.weightOf(user1), 11);

        // Create new token and mint again to increase streak
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Weight should be 12 (10 + 2) for streak of 2
        assertEq(aeye.weightOf(user1), 12);

        // Test max streak cap at 10
        for (uint i = 0; i < 8; i++) {
            vm.startPrank(owner);
            aeye.createToken(string(abi.encodePacked("test-metadata", i + 3)));
            vm.stopPrank();

            vm.startPrank(user1);
            aeye.mint{value: 0.0008 ether}();
            vm.stopPrank();
        }

        // Weight should be 20 (10 + 10) for streak of 10 or more
        assertEq(aeye.weightOf(user1), 20);
    }

    function test_CommunityRewards() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check community rewards for token 1
        uint256 communityRewards = aeye.communityRewards(1);
        assertTrue(communityRewards > 0, "Community rewards should be greater than 0");

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check that community rewards were distributed
        // Note: The rewards are now stored in accRewardPerShare instead of being zeroed out
        assertTrue(aeye.accRewardPerShare(1) > 0, "Rewards should be distributed to accRewardPerShare");
    }

    function test_SupportsInterface() public {
        // Test ERC1155 interface
        assertTrue(aeye.supportsInterface(0xd9b67a26));
        // Test AccessControl interface
        assertTrue(aeye.supportsInterface(0x7965db0b));
        // Test non-supported interface
        assertFalse(aeye.supportsInterface(0x12345678));
    }

    function test_Uri() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        assertEq(aeye.uri(1), "test-metadata");
    }

    function test_HasMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        assertTrue(aeye.hasMetadata(1));
        assertFalse(aeye.hasMetadata(2));
    }

    function test_WeightOf() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Test weight for new user (streak = 0)
        assertEq(aeye.weightOf(user1), 10);

        // Test weight for user with streak = 1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        assertEq(aeye.weightOf(user1), 11);

        // Test weight for user with streak = 2
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        assertEq(aeye.weightOf(user1), 12);

        // Test weight cap at streak = 10
        for (uint i = 0; i < 8; i++) {
            vm.startPrank(owner);
            aeye.createToken(string(abi.encodePacked("test-metadata", i + 3)));
            vm.stopPrank();

            vm.startPrank(user1);
            aeye.mint{value: 0.0008 ether}();
            vm.stopPrank();
        }

        assertEq(aeye.weightOf(user1), 20); // 10 + 10 (capped at 10)
    }

    function test_UnclaimedRewards() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check unclaimed rewards
        uint256 rewards = aeye.unclaimedRewards(user1);
        assertTrue(rewards > 0, "User should have unclaimed rewards");

        // Claim rewards
        vm.startPrank(user1);
        aeye.claimRewards();
        vm.stopPrank();

        // Check that rewards are now claimed
        assertEq(aeye.unclaimedRewards(user1), 0, "User should have no unclaimed rewards after claiming");
    }

    function test_WeightSnapshot() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check weight snapshot
        assertEq(aeye.weightSnapshot(1, user1), 11, "Weight snapshot should be 11 for streak of 1");
    }

    function test_TotalWeightPerCycle() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total weight
        assertEq(aeye.totalWeightPerCycle(1), 11, "Total weight should be 11 for one user with streak of 1");

        // Mint with user2
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total weight increased
        assertEq(aeye.totalWeightPerCycle(1), 22, "Total weight should be 22 for two users with streak of 1");
    }

    function test_LastClaimedToken() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Create new token to trigger reward distribution
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // Check initial last claimed token
        assertEq(aeye.lastClaimedToken(user1), 0, "Last claimed token should be 0 initially");

        // Claim rewards
        vm.startPrank(user1);
        aeye.claimRewards();
        vm.stopPrank();

        // Check last claimed token updated
        assertEq(aeye.lastClaimedToken(user1), 2, "Last claimed token should be updated after claiming");
    }

    function test_TotalMintsPerToken() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        // Initial state should be 0
        assertEq(aeye.mintsPerToken(1), 0, "Initial total mints should be 0");

        // Mint with user1
        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total mints increased to 1
        assertEq(aeye.mintsPerToken(1), 1, "Total mints should be 1 after first mint");

        // Mint again with user1 (same user can mint multiple times)
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total mints increased to 2
        assertEq(aeye.mintsPerToken(1), 2, "Total mints should be 2 after second mint");

        // Mint with user2
        vm.deal(user2, 1 ether);
        vm.startPrank(user2);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total mints increased to 3
        assertEq(aeye.mintsPerToken(1), 3, "Total mints should be 3 after third mint");

        // Create new token
        vm.startPrank(owner);
        aeye.createToken("test-metadata2");
        vm.stopPrank();

        // New token should start with 0 mints
        assertEq(aeye.mintsPerToken(2), 0, "New token should start with 0 mints");

        // Mint with user1 on new token
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();

        // Check total mints for new token
        assertEq(aeye.mintsPerToken(2), 1, "New token should have 1 mint");
        // Previous token should still have 3 mints
        assertEq(aeye.mintsPerToken(1), 3, "Previous token should maintain its mint count");
    }
}
