// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    BBitsEmoji, 
    BBitsCheckIn, 
    BBitsBurner,
    console
} from "./utils/BBitsTestUtils.sol";
import {IBBitsEmoji} from "../src/interfaces/IBBitsEmoji.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @dev forge test --match-contract BBitsEmojiTest -vvv --gas-report
///      forge coverage --report lcov
contract BBitsEmojiTest is BBitsTestUtils, IBBitsEmoji {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);
        vm.deal(user0, 1e18);
        vm.deal(user1, 1e18);

        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        emoji = new BBitsEmoji(owner, address(burner), checkIn);

        /// @dev owner set up
        addArt();
        vm.startPrank(owner);
        emoji.setPaused(false);
        emoji.mint();
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(address(emoji.burner()), address(burner));
        assertEq(address(emoji.checkIn()), address(checkIn));
        assertEq(emoji.burnPercentage(), 4000);
        assertEq(emoji.mintDuration(), 1 days);
        assertEq(emoji.mintPrice(), 0.0005 ether);
        assertEq(emoji.totalEntries(0), 1);
        assertEq(emoji.raffleAmount(), 0);
        assertEq(emoji.burnAmount(), 0);
        assertEq(emoji.currentDay(), 1);
    }

    /// RAFFLE ///

    function testMintEntryRevertConditions() public {
        vm.expectRevert(MustPayMintPrice.selector);
        emoji.mint();
    }

    function testMintEntrySuccessConditions() public prank(user0) {
        assertEq(emoji.willMintSettleRaffle(), false);

        (
            uint256 tokenId,
            uint256 mints,
            uint256 rewards,
            uint256 burned,
            address winner,
            uint256 start
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(start, block.timestamp);

        vm.expectRevert(InvalidIndex.selector);
        Entry memory entry = emoji.userEntry(1, 1);

        assertEq(emoji.totalBalanceOf(user0), 0);

        /// Mint and enter raffle
        uint256 mintPrice = emoji.mintPrice();
        emoji.mint{value: mintPrice}();

        (
            tokenId,
            mints,
            rewards,
            burned,
            winner,
            start
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 2);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(start, block.timestamp);

        entry = emoji.userEntry(1, 1);
        assertEq(entry.user, user0);
        assertEq(entry.weight, 1);

        assertEq(emoji.totalBalanceOf(user0), 1);
        
        /// remint but no raffle changes except mints
        emoji.mint{value: mintPrice}();

        (
            tokenId,
            mints,
            rewards,
            burned,
            winner,
            start
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 3);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(start, block.timestamp);

        entry = emoji.userEntry(1, 1);
        assertEq(entry.user, user0);
        assertEq(entry.weight, 1);

        assertEq(emoji.totalBalanceOf(user0), 2);
    }

    /// checkin discount

    /// settlement

    /// OWNER ///

    /// ART ///

    function testDraw() public view {
        string memory image = emoji.uri(1);
        image;
        //console.log(image);
    }
}