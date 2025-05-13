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
        assertTrue(aeye.getTotalRewards(user1) > 0);
        assertTrue(aeye.getTotalRewards(user2) > 0);
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
        uint256 rewards = aeye.getTotalRewards(user1);

        vm.startPrank(user1);
        aeye.claimRewards();
        vm.stopPrank();

        assertEq(user1.balance, initialBalance + rewards);
        assertEq(aeye.getTotalRewards(user1), 0);
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

    function testFail_MintWithoutMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0008 ether}();
        vm.stopPrank();
    }

    function testFail_MintInsufficientPayment() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.deal(user1, 1 ether);
        vm.startPrank(user1);
        aeye.mint{value: 0.0004 ether}();
        vm.stopPrank();
    }

    function testFail_NonOwnerSetPercentages() public {
        vm.startPrank(user1);
        aeye.setPercentages(3000, 4000, 3000);
        vm.stopPrank();
    }

    function testFail_NonOwnerUpdateMetadata() public {
        vm.startPrank(owner);
        aeye.setPaused(false);
        aeye.createToken("test-metadata");
        vm.stopPrank();

        vm.startPrank(user1);
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
        uint256 user1Rewards = aeye.getTotalRewards(user1);
        uint256 user2Rewards = aeye.getTotalRewards(user2);
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
            assertTrue(aeye.getTotalRewards(users[i]) > 0);
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
        uint256 user1Rewards = aeye.getTotalRewards(user1);
        uint256 user2Rewards = aeye.getTotalRewards(user2);
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
        assertEq(aeye.getTotalRewards(user1), 0);
        assertEq(aeye.getTotalRewards(user2), 0);
        assertEq(aeye.getTotalRewards(user3), 0);
    }
}
