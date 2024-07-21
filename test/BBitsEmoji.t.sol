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

        
        /// remint but no raffle changes except mints
    }

    /// ART ///

    /// OWNER ///

    /*
    function testGasFuzz() public {
        //_loops = bound(_loops, 10, 10000);

        vm.prank(owner);
        emoji.mint();

        for(uint256 i; i < 1; i++) {
            address user = makeAddr(Strings.toString(uint256(keccak256(abi.encodePacked(i, block.number)))));
            vm.deal(user, 1e18);
            vm.startPrank(user);
            emoji.mint{value: 1e16}();
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1.01 days);

        vm.prank(owner);
        emoji.mint();
    }
    */

    /// UTILS ///

    function addArt() internal prank(owner) {
        /// Load some art
        NamedBytes[] memory placeholder = new NamedBytes[](1);
        /// Background 1
        placeholder[0] = NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: 'AAA'
        });
        emoji.addArt(0, placeholder);
        /// Background 2
        placeholder[0] = NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#A71FEF"/>',
            name: 'BBB'
        });
        emoji.addArt(1, placeholder);
        /// Head
        placeholder[0] = NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: 'CCC'
        });
        emoji.addArt(2, placeholder);
        /// Hair 1
        placeholder[0] = NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: 'DDD'
        });
        emoji.addArt(3, placeholder);
        /// Hair 2
        placeholder[0] = NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#FFB800"/>',
            name: 'EEE'
        });
        emoji.addArt(4, placeholder);
        /// Eyes 1
        placeholder[0] = NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: 'FFF'
        });
        emoji.addArt(5, placeholder);
        /// Eyes 2
        placeholder[0] = NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="black"/>',
            name: 'GGG'
        });
        emoji.addArt(6, placeholder);
        /// Mouth 1
        placeholder[0] = NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: 'HHH'
        });
        emoji.addArt(7, placeholder);
        /// Mouth 2
        placeholder[0] = NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#FF00FF"/>',
            name: 'III'
        });
        emoji.addArt(8, placeholder);
    }
}