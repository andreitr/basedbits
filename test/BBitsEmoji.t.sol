// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    BBitsEmoji, 
    BBitsCheckIn, 
    BBitsBurner,
    console
} from "./utils/BBitsTestUtils.sol";
import {ERC721, IERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IBBitsEmoji} from "../src/interfaces/IBBitsEmoji.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @dev forge test --match-contract BBitsEmojiTest -vvv --gas-report
contract BBitsEmojiTest is BBitsTestUtils, IBBitsEmoji {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);
        vm.deal(user0, 1e18);
        vm.deal(user1, 1e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        emoji = new BBitsEmoji(owner, address(burner), checkIn);

        /// @dev Owner contract set up
        addArt();
        vm.startPrank(owner);
        emoji.setPaused(false);
        emoji.mint();

        /// @dev Give users NFTs for testing
        basedBits.transferFrom(owner, user0, ownerTokenIds[0]);
        basedBits.transferFrom(owner, user1, ownerTokenIds[1]);
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(address(emoji.burner()), address(burner));
        assertEq(address(emoji.checkIn()), address(checkIn));
        assertEq(emoji.burnPercentage(), 2000);
        assertEq(emoji.mintDuration(), 8 hours);
        assertEq(emoji.mintPrice(), 0.0005 ether);
        assertEq(emoji.totalEntries(0), 1);
        assertEq(emoji.raffleAmount(), 0);
        assertEq(emoji.burnAmount(), 0);
        assertEq(emoji.currentRound(), 1);
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
            uint256 startedAt,
            uint256 settledAt
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        vm.expectRevert(InvalidIndex.selector);
        Entry memory entry = emoji.userEntryByIndex(1, 1);
        assertEq(entry.weight, emoji.userEntryByAddress(1, user0));

        assertEq(emoji.totalBalanceOf(user0), 0);
        assertEq(emoji.totalEntries(1), 1);

        /// Mint and enter raffle
        uint256 mintPrice = emoji.mintPrice();
        emoji.mint{value: mintPrice}();

        (
            tokenId,
            mints,
            rewards,
            burned,
            winner,
            startedAt,
            settledAt
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 2);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        entry = emoji.userEntryByIndex(1, 1);
        assertEq(entry.user, user0);
        assertEq(entry.weight, 1);
        assertEq(entry.weight, emoji.userEntryByAddress(1, user0));

        assertEq(emoji.totalBalanceOf(user0), 1);
        assertEq(emoji.totalEntries(1), 2);
        
        /// mint again but no raffle changes except mints amount
        emoji.mint{value: mintPrice}();

        (
            tokenId,
            mints,
            rewards,
            burned,
            winner,
            startedAt,
            settledAt
        ) = emoji.raffleInfo(1);
        assertEq(tokenId, 1);
        assertEq(mints, 3);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        entry = emoji.userEntryByIndex(1, 1);
        assertEq(entry.user, user0);
        assertEq(entry.weight, 1);
        assertEq(entry.weight, emoji.userEntryByAddress(1, user0));

        assertEq(emoji.totalBalanceOf(user0), 2);
        /// @dev total entries not updated as expected
        assertEq(emoji.totalEntries(1), 2);
    }

    function testStreakDiscount() public {
        /// Mint price with no streak
        uint256 mintPrice = emoji.mintPrice();
        assertEq(emoji.userMintPrice(user0), mintPrice);

        /// Set streak for 10% discount
        setCheckInStreak(user0, 10);
        assertEq(
            emoji.userMintPrice(user0),
            mintPrice - ((mintPrice * 10) / 100)
        );

        /// Set streak for maximum discount
        /// @dev different user for simplicity
        setCheckInStreak(user1, 100);
        assertEq(
            emoji.userMintPrice(user1),
            mintPrice - ((mintPrice * 90) / 100)
        );
    }

    function testMintSettlement() public prank(user0) {
        assertEq(emoji.willMintSettleRaffle(), false);

        (
            ,
            uint256 mints,
            uint256 rewards,
            uint256 burned,
            address winner,
            uint256 startedAt,
            uint256 settledAt
        ) = emoji.raffleInfo(1);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        /// Balances and reward/burn amounts before
        assertEq(address(emoji).balance, 0);
        assertEq(emoji.raffleAmount(), 0);
        assertEq(emoji.burnAmount(), 0);

        /// Mint and enter raffle
        uint256 mintPrice = emoji.mintPrice();
        emoji.mint{value: mintPrice}();

        (
            ,
            mints,
            rewards,
            burned,
            winner,
            startedAt,
            settledAt
        ) = emoji.raffleInfo(1);
        assertEq(mints, 2);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        assertEq(emoji.totalBalanceOf(user0), 1);
        assertEq(emoji.totalEntries(1), 2);

        /// Balances and reward/burn amounts after
        assertEq(address(emoji).balance, mintPrice);
        assertEq(
            emoji.raffleAmount(),
            (8000 * mintPrice) / 10_000
        );
        assertEq(
            emoji.burnAmount(),
            (2000 * mintPrice) / 10_000
        );

        uint256 ownerBalanceBeforeSettlement = address(owner).balance;
        uint256 user0BalanceBeforeSettlement = address(user0).balance;

        /// Settle
        vm.warp(block.timestamp + 1.01 days);

        /// @dev Simple logic for winner given only two entrants
        address expectedWinner;
        (uint256(keccak256(abi.encodePacked(block.number, block.timestamp))) % 2 == 0) ? 
            expectedWinner = owner : 
            expectedWinner = user0;

        vm.expectEmit(true, true, true, true);
        emit End(
            1, 
            mints, 
            expectedWinner, 
            (8000 * mintPrice) / 10_000, 
            (2000 * mintPrice) / 10_000
        );
        vm.expectEmit(true, true, true, true);
        emit Start(2);
        emoji.mint();

        (
            ,
            mints,
            rewards,
            burned,
            winner,
            ,
            settledAt
        ) = emoji.raffleInfo(1);
        assertEq(mints, 2);
        assertEq(rewards, (8000 * mintPrice) / 10_000);
        assertEq(burned, (2000 * mintPrice) / 10_000);
        assertEq(winner, expectedWinner);
        assertEq(settledAt, block.timestamp);

        assertEq(address(emoji).balance, 0);
        assertEq(emoji.raffleAmount(), 0);
        assertEq(emoji.burnAmount(), 0);

        (expectedWinner == owner) ? 
            assertEq(ownerBalanceBeforeSettlement + (8000 * mintPrice) / 10_000, address(owner).balance) : 
            assertEq(user0BalanceBeforeSettlement + (8000 * mintPrice) / 10_000, address(user0).balance);

        /// New raffle info
        (
            ,
            mints,
            rewards,
            burned,
            winner,
            startedAt,
            settledAt
        ) = emoji.raffleInfo(2);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);
    }

    /// OWNER ///

    function testSetPaused() public prank(owner) {
        /// Set Paused
        emoji.setPaused(true);
        assertEq(emoji.paused(), true);

        vm.expectRevert();
        emoji.mint{value: 1e18}();

        /// Unpause
        emoji.setPaused(false);
        assertEq(emoji.paused(), false);

        emoji.mint{value: 1e18}();
    }

    function testSetMintPrice() public prank(owner) {
        assertEq(emoji.mintPrice(), 0.0005 ether);
        emoji.setMintPrice(0.1 ether);
        assertEq(emoji.mintPrice(), 0.1 ether);
        vm.stopPrank();

        vm.startPrank(user0);
        vm.expectRevert(MustPayMintPrice.selector);
        emoji.mint{value: 0.1 ether - 1}();
        vm.stopPrank();
    }

    function testAddArtRevertConditions() public prank(owner) {
        /// Invalid Array
        NamedBytes[] memory placeholder = new NamedBytes[](1);
        placeholder[0] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });
        vm.expectRevert(InvalidArray.selector);
        emoji.addArt(9, placeholder);

        /// Input zero
        placeholder = new NamedBytes[](0);
        vm.expectRevert(InputZero.selector);
        emoji.addArt(0, placeholder);
    }

    function testAddArtSuccessConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](1);
        placeholder[0] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });

        emoji.addArt(0, placeholder);

        (bytes memory core, bytes memory name) = emoji.metadata(0, 1);
        assertEq(core, 'Arty art');
        assertEq(name, 'ART');
    }

    /// ERC1155SUPPLY ///

    function testERC1155SupplyTransfer() public prank(owner) {
        assertEq(emoji.totalBalanceOf(owner), 1);

        emoji.mint{value: 1e18}();
        assertEq(emoji.totalBalanceOf(owner), 2);
        assertEq(emoji.totalBalanceOf(user0), 0);

        emoji.safeTransferFrom(owner, user0, 1, 1, "");

        assertEq(emoji.totalBalanceOf(owner), 1);
        assertEq(emoji.totalBalanceOf(user0), 1);
    }

    function testERC1155SupplyTransferBatch() public prank(owner) {
        assertEq(emoji.totalBalanceOf(owner), 1);

        emoji.mint{value: 0.1e18}();
        vm.warp(block.timestamp + 1.01 days);
        emoji.mint{value: 0.1e18}();

        assertEq(emoji.totalBalanceOf(owner), 3);
        assertEq(emoji.totalBalanceOf(user0), 0);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2; 

        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 1; 

        emoji.safeBatchTransferFrom(owner, user0, ids, values, "");

        assertEq(emoji.totalBalanceOf(owner), 1);
        assertEq(emoji.totalBalanceOf(user0), 2);
    }

    /// ART ///

    function testDraw() public view {
        string memory image = emoji.uri(1);
        image;
        //console.log(image);
    }
}