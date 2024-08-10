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

    function testSetMintDuration() public prank(owner) {
        assertEq(emoji.mintDuration(), 8 hours);
        emoji.setMintDuration(12 hours);
        assertEq(emoji.mintDuration(), 12 hours);
    }

    function testSetBurnPercentage() public prank(owner) {
        /// Burn percentage over 10K
        vm.expectRevert(InvalidPercentage.selector);
        emoji.setBurnPercentage(10_001);

        /// Set
        assertEq(emoji.burnPercentage(), 2000);
        emoji.setBurnPercentage(8000);
        assertEq(emoji.burnPercentage(), 8000);
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

    function testRemoveArtRevertConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](2);
        placeholder[0] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });
        placeholder[1] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });
        emoji.addArt(0, placeholder);

        /// Invalid array
        uint256[] memory indices = new uint256[](0);
        vm.expectRevert(InvalidArray.selector);
        emoji.removeArt(9, indices);

        /// Input zero
        vm.expectRevert(InputZero.selector);
        emoji.removeArt(0, indices);

        /// Invalid index
        indices = new uint256[](2);
        indices[0] = 9;
        vm.expectRevert(InvalidIndex.selector);
        emoji.removeArt(0, indices);

        /// Monotonically increasing
        indices[0] = 0;
        indices[1] = 1;
        vm.expectRevert(IndicesMustBeMonotonicallyDecreasing.selector);
        emoji.removeArt(0, indices);
    }

    function testRemoveArtSuccessConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](2);
        placeholder[0] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });
        placeholder[1] = NamedBytes({
            core: 'Arty art',
            name: 'ART'
        });
        emoji.addArt(0, placeholder);

        (bytes memory core, bytes memory name) = emoji.metadata(0, 0);
        assertEq(core, '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>');
        assertEq(name, 'AAA');

        /// Remove one
        uint256[] memory indices = new uint256[](1);
        emoji.removeArt(0, indices);

        (core, name) = emoji.metadata(0, 0);
        assertEq(core, 'Arty art');
        assertEq(name, 'ART');

        vm.expectRevert();
        (core, name) = emoji.metadata(0, 2);

        /// Add Two more
        placeholder[0] = NamedBytes({
            core: 'Arty art and things',
            name: 'ARTT'
        });
        placeholder[1] = NamedBytes({
            core: 'Arty',
            name: 'ARTY'
        });
        emoji.addArt(0, placeholder);

        /// Now remove 3
        indices = new uint256[](3);
        indices[0] = 2;
        indices[1] = 1;
        indices[2] = 0;
        emoji.removeArt(0, indices);

        (core, name) = emoji.metadata(0, 0);
        assertEq(core, 'Arty');
        assertEq(name, 'ARTY');
    }

    function testSetArt() public prank(owner) {
        uint256[] memory indices = new uint256[](1);
        emoji.removeArt(0, indices);

        vm.expectRevert();
        emoji.uri(0);

        /// Load some art
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](1);
        /// Background 1
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: 'AAA'
        });
        emoji.addArt(0, placeholder);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: 'AAAA'
        });
        emoji.addArt(0, placeholder);
        /// Background 2
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#A71FEF"/>',
            name: 'BBBB'
        });
        emoji.addArt(1, placeholder);
        /// Head
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: 'CCCC'
        });
        emoji.addArt(2, placeholder);
        /// Hair 1
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: 'DDDD'
        });
        emoji.addArt(3, placeholder);
        /// Hair 2
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#FFB800"/>',
            name: 'EEEE'
        });
        emoji.addArt(4, placeholder);
        /// Eyes 1
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: 'FFFF'
        });
        emoji.addArt(5, placeholder);
        /// Eyes 2
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="black"/>',
            name: 'GGGG'
        });
        emoji.addArt(6, placeholder);
        /// Mouth 1
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: 'HHHH'
        });
        emoji.addArt(7, placeholder);
        /// Mouth 2
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#FF00FF"/>',
            name: 'IIII'
        });
        emoji.addArt(8, placeholder);

        uint256 mintPrice = emoji.mintPrice();
        vm.warp(block.timestamp + 1);
        emoji.mint{value: mintPrice}();
        vm.warp(block.timestamp + 1);
        emoji.mint{value: mintPrice}();
        vm.warp(block.timestamp + 1);

        string memory image0 = emoji.uri(0);

        /// Input Zero
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert(InputZero.selector);
        emoji.setArt(tokenIds);

        tokenIds = new uint256[](1);
        emoji.setArt(tokenIds);

        string memory image1 = emoji.uri(0);
        assertNotEq(image0, image1);
    }

    function testSetDescription() public prank(owner) {
        assertEq(
            emoji.description(), 
            'Every 8 hours, a new Emobit is born! 80% of mint proceeds are raffled off to one lucky winner, the rest are used to burn BBITS tokens. The more Emobits you hold, the more raffle entries you get. Check out emobits.fun for more.'
        );
        bytes memory newDescription = 'ARTY ART';
        emoji.setDescription(newDescription);
        assertEq(
            emoji.description(), 
            newDescription
        );
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