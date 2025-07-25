// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBMintRaffleNFT, BBitsCheckIn, BBitsBurner, console} from "@test/utils/BBitsTestUtils.sol";
import {ERC721, IERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IBBMintRaffleNFT} from "@src/interfaces/IBBMintRaffleNFT.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @dev forge test --match-contract BBMintRaffleNFTTest -vvv
contract BBMintRaffleNFTTest is BBitsTestUtils, IBBMintRaffleNFT {
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
        mintRaffle = new BBMintRaffleNFT(owner, user0, address(burner), 100, checkIn);

        unpauseLegacyCheckin();

        /// @dev Owner contract set up
        addArt();
        vm.startPrank(owner);
        mintRaffle.setPaused(false);
        mintRaffle.mint();

        /// @dev Give users NFTs for testing
        basedBits.transferFrom(owner, user0, ownerTokenIds[0]);
        basedBits.transferFrom(owner, user1, ownerTokenIds[1]);
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(address(mintRaffle.burner()), address(burner));
        assertEq(address(mintRaffle.checkIn()), address(checkIn));
        assertEq(address(mintRaffle.artist()), address(user0));
        assertEq(mintRaffle.cap(), 100);
        assertEq(mintRaffle.burnPercentage(), 2000);
        assertEq(mintRaffle.mintDuration(), 4 hours);
        assertEq(mintRaffle.mintPrice(), 0.0008 ether);
        assertEq(mintRaffle.totalEntries(0), 1);
        assertEq(mintRaffle.currentMintArtistReward(), 0);
        assertEq(mintRaffle.currentMintBurnAmount(), 0);
        assertEq(mintRaffle.currentMint(), 2);
    }

    /// RAFFLE ///

    function testMintEntryRevertConditions() public prank(user1) {
        vm.expectRevert(MustPayMintPrice.selector);
        mintRaffle.mint();

        /// Cap
        uint256 cap = mintRaffle.cap();
        uint256 supply = mintRaffle.currentMint();
        uint256 timestamp = vm.getBlockTimestamp();
        while (supply < cap) {
            mintRaffle.mint{value: 0.001 ether}();
            vm.warp(timestamp += 1.01 days);
            supply = mintRaffle.currentMint();
        }

        vm.expectRevert(CapExceeded.selector);
        mintRaffle.mint{value: 0.001 ether}();

        vm.expectRevert(CapExceeded.selector);
        (bool s,) = address(mintRaffle).call{value: 1e16}("");
        s;
    }

    function testMintEntrySuccessConditions() public prank(user1) {
        assertEq(mintRaffle.willMintSettleRaffle(), false);

        (
            uint256 tokenId,
            ,
            uint256 mints,
            uint256 rewards,
            uint256 burned,
            address winner,
            uint256 startedAt,
            uint256 settledAt
        ) = mintRaffle.mintById(2);
        assertEq(tokenId, 2);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        vm.expectRevert(InvalidIndex.selector);
        Entry memory entry = mintRaffle.userEntryByIndex(2, 1);
        assertEq(entry.weight, mintRaffle.userEntryByAddress(2, user1));

        assertEq(mintRaffle.totalBalanceOf(user1), 0);
        assertEq(mintRaffle.totalEntries(2), 1);

        /// Mint and enter raffle
        uint256 mintPrice = mintRaffle.mintPrice();
        mintRaffle.mint{value: mintPrice}();

        (tokenId,, mints, rewards, burned, winner, startedAt, settledAt) = mintRaffle.mintById(2);
        assertEq(tokenId, 2);
        assertEq(mints, 2);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        entry = mintRaffle.userEntryByIndex(2, 1);
        assertEq(entry.user, user1);
        assertEq(entry.weight, 1);
        assertEq(entry.weight, mintRaffle.userEntryByAddress(2, user1));

        assertEq(mintRaffle.totalBalanceOf(user1), 1);
        assertEq(mintRaffle.totalEntries(2), 2);

        /// mint again but no raffle changes except mints amount
        mintRaffle.mint{value: mintPrice}();

        (tokenId,, mints, rewards, burned, winner, startedAt, settledAt) = mintRaffle.mintById(2);
        assertEq(tokenId, 2);
        assertEq(mints, 3);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        entry = mintRaffle.userEntryByIndex(2, 1);
        assertEq(entry.user, user1);
        assertEq(entry.weight, 1);
        assertEq(entry.weight, mintRaffle.userEntryByAddress(2, user1));

        assertEq(mintRaffle.totalBalanceOf(user1), 2);
        /// @dev total entries not updated as expected
        assertEq(mintRaffle.totalEntries(2), 2);
    }

    function testStreakDiscount() public {
        /// Mint price with no streak
        uint256 mintPrice = mintRaffle.mintPrice();
        assertEq(mintRaffle.userMintPrice(user0), mintPrice);

        /// Set streak for 10% discount
        setCheckInStreak(user0, 10);
        assertEq(mintRaffle.userMintPrice(user0), mintPrice - ((mintPrice * 10) / 100));

        /// Set streak for maximum discount
        /// @dev different user for simplicity
        setCheckInStreak(user1, 100);
        assertEq(mintRaffle.userMintPrice(user1), mintPrice - ((mintPrice * 90) / 100));
    }

    function testStreakDiscountFirstOnly() public prank(user0) {
        /// Set streak for 10% discount
        uint256 mintPrice = mintRaffle.mintPrice();
        setCheckInStreak(user0, 10);

        /// Avoid free mint for a new round
        vm.stopPrank();
        vm.startPrank(user1);
        mintRaffle.mint{value: mintPrice}();
        vm.stopPrank();
        vm.startPrank(user0);

        /// Discount for first in new round
        assertEq(mintRaffle.userMintPrice(user0), mintPrice - ((mintPrice * 10) / 100));

        /// Second Mint the discount not applied
        mintRaffle.mint{value: mintPrice}();
        assertEq(mintRaffle.userMintPrice(user0), mintPrice);
    }

    function testMintSettlement() public prank(user1) {
        assertEq(mintRaffle.willMintSettleRaffle(), false);

        (,, uint256 mints, uint256 rewards, uint256 burned, address winner, uint256 startedAt, uint256 settledAt) =
            mintRaffle.mintById(2);
        assertEq(mints, 1);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        /// Balances and reward/burn amounts before
        assertEq(address(mintRaffle).balance, 0);
        assertEq(mintRaffle.currentMintArtistReward(), 0);
        assertEq(mintRaffle.currentMintBurnAmount(), 0);

        /// Mint and enter raffle
        uint256 mintPrice = mintRaffle.mintPrice();
        mintRaffle.mint{value: mintPrice}();

        (,, mints, rewards, burned, winner, startedAt, settledAt) = mintRaffle.mintById(2);
        assertEq(mints, 2);
        assertEq(rewards, 0);
        assertEq(burned, 0);
        assertEq(winner, address(0));
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);

        assertEq(mintRaffle.totalBalanceOf(user1), 1);
        assertEq(mintRaffle.totalEntries(2), 2);

        /// Balances and reward/burn amounts after
        assertEq(address(mintRaffle).balance, mintPrice);
        assertEq(mintRaffle.currentMintArtistReward(), (8000 * mintPrice) / 10_000);
        assertEq(mintRaffle.currentMintBurnAmount(), (2000 * mintPrice) / 10_000);

        uint256 user0BalanceBeforeSettlement = address(user0).balance;

        /// Settle
        vm.warp(block.timestamp + 1.01 days);

        /// @dev Simple logic for winner given only two entrants
        address expectedWinner;
        (uint256(keccak256(abi.encodePacked(block.number, block.timestamp))) % 2 == 0)
            ? expectedWinner = owner
            : expectedWinner = user1;

        vm.expectEmit(true, true, true, true);
        emit End(2, mints, expectedWinner, (8000 * mintPrice) / 10_000, (2000 * mintPrice) / 10_000);
        vm.expectEmit(true, true, true, true);
        emit Start(4);
        mintRaffle.mint();

        (,, mints, rewards, burned, winner,, settledAt) = mintRaffle.mintById(2);
        assertEq(mints, 2);
        assertEq(rewards, (8000 * mintPrice) / 10_000);
        assertEq(burned, (2000 * mintPrice) / 10_000);
        assertEq(winner, expectedWinner);
        assertEq(settledAt, block.timestamp);
        assertEq(mintRaffle.balanceOf(winner, 3), 1);

        assertEq(address(mintRaffle).balance, 0);
        assertEq(mintRaffle.currentMintArtistReward(), 0);
        assertEq(mintRaffle.currentMintBurnAmount(), 0);
        assertEq(user0BalanceBeforeSettlement + (8000 * mintPrice) / 10_000, address(user0).balance);

        /// New raffle info
        (,, mints, rewards, burned, winner, startedAt, settledAt) = mintRaffle.mintById(4);
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
        mintRaffle.setPaused(true);
        assertEq(mintRaffle.paused(), true);

        vm.expectRevert();
        mintRaffle.mint{value: 1e18}();

        /// Unpause
        mintRaffle.setPaused(false);
        assertEq(mintRaffle.paused(), false);

        mintRaffle.mint{value: 1e18}();
    }

    function testSetMintPrice() public prank(owner) {
        assertEq(mintRaffle.mintPrice(), 0.0008 ether);
        mintRaffle.setMintPrice(0.1 ether);
        assertEq(mintRaffle.mintPrice(), 0.1 ether);
        vm.stopPrank();

        vm.startPrank(user0);
        vm.expectRevert(MustPayMintPrice.selector);
        mintRaffle.mint{value: 0.1 ether - 1}();
        vm.stopPrank();
    }

    function testSetMintDuration() public prank(owner) {
        assertEq(mintRaffle.mintDuration(), 4 hours);
        mintRaffle.setMintDuration(12 hours);
        assertEq(mintRaffle.mintDuration(), 12 hours);
    }

    function testSetBurnPercentage() public prank(owner) {
        /// Burn percentage over 10K
        vm.expectRevert(InvalidPercentage.selector);
        mintRaffle.setBurnPercentage(10_001);

        /// Set
        assertEq(mintRaffle.burnPercentage(), 2000);
        mintRaffle.setBurnPercentage(5000);
        assertEq(mintRaffle.burnPercentage(), 5000);
    }

    function testAddArtRevertConditions() public prank(owner) {
        /// Invalid Array
        NamedBytes[] memory placeholder = new NamedBytes[](1);
        placeholder[0] = NamedBytes({core: "Arty art", name: "ART"});
        vm.expectRevert(InvalidArray.selector);
        mintRaffle.addArt(9, placeholder);

        /// Input zero
        placeholder = new NamedBytes[](0);
        vm.expectRevert(InputZero.selector);
        mintRaffle.addArt(0, placeholder);
    }

    function testAddArtSuccessConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](1);
        placeholder[0] = NamedBytes({core: "Arty art", name: "ART"});
        mintRaffle.addArt(0, placeholder);

        (bytes memory core, bytes memory name) = mintRaffle.metadata(0, 1);
        assertEq(core, "Arty art");
        assertEq(name, "ART");
    }

    function testRemoveArtRevertConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](2);
        placeholder[0] = NamedBytes({core: "Arty art", name: "ART"});
        placeholder[1] = NamedBytes({core: "Arty art", name: "ART"});
        mintRaffle.addArt(0, placeholder);

        /// Invalid array
        uint256[] memory indices = new uint256[](0);
        vm.expectRevert(InvalidArray.selector);
        mintRaffle.removeArt(9, indices);

        /// Input zero
        vm.expectRevert(InputZero.selector);
        mintRaffle.removeArt(0, indices);

        /// Invalid index
        indices = new uint256[](2);
        indices[0] = 9;
        vm.expectRevert(InvalidIndex.selector);
        mintRaffle.removeArt(0, indices);

        /// Monotonically increasing
        indices[0] = 0;
        indices[1] = 1;
        vm.expectRevert(IndicesMustBeMonotonicallyDecreasing.selector);
        mintRaffle.removeArt(0, indices);
    }

    function testRemoveArtSuccessConditions() public prank(owner) {
        NamedBytes[] memory placeholder = new NamedBytes[](2);
        placeholder[0] = NamedBytes({core: "Arty art", name: "ART"});
        placeholder[1] = NamedBytes({core: "Arty art", name: "ART"});
        mintRaffle.addArt(0, placeholder);

        (bytes memory core, bytes memory name) = mintRaffle.metadata(0, 0);
        assertEq(core, '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>');
        assertEq(name, "AAAe");

        /// Remove one
        uint256[] memory indices = new uint256[](1);
        mintRaffle.removeArt(0, indices);

        (core, name) = mintRaffle.metadata(0, 0);
        assertEq(core, "Arty art");
        assertEq(name, "ART");

        vm.expectRevert();
        (core, name) = mintRaffle.metadata(0, 2);

        /// Add Two more
        placeholder[0] = NamedBytes({core: "Arty art and things", name: "ARTT"});
        placeholder[1] = NamedBytes({core: "Arty", name: "ARTY"});
        mintRaffle.addArt(0, placeholder);

        /// Now remove 3
        indices = new uint256[](3);
        indices[0] = 2;
        indices[1] = 1;
        indices[2] = 0;
        mintRaffle.removeArt(0, indices);

        (core, name) = mintRaffle.metadata(0, 0);
        assertEq(core, "Arty");
        assertEq(name, "ARTY");
    }

    function testSetArt() public prank(owner) {
        uint256[] memory indices = new uint256[](1);
        mintRaffle.removeArt(0, indices);

        vm.expectRevert();
        mintRaffle.uri(0);

        /// Load some art
        IBBMintRaffleNFT.NamedBytes[] memory placeholder = new IBBMintRaffleNFT.NamedBytes[](1);
        /// Background
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: "AAAA"
        });
        mintRaffle.addArt(0, placeholder);
        /// Face
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: "CCCC"
        });
        mintRaffle.addArt(1, placeholder);
        /// Hair
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: "DDDD"
        });
        mintRaffle.addArt(2, placeholder);
        /// Eyes
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: "FFFF"
        });
        mintRaffle.addArt(3, placeholder);
        /// Mouth
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: "HHHH"
        });
        mintRaffle.addArt(4, placeholder);

        uint256 mintPrice = mintRaffle.mintPrice();
        vm.warp(block.timestamp + 1);
        mintRaffle.mint{value: mintPrice}();
        vm.warp(block.timestamp + 1);
        mintRaffle.mint{value: mintPrice}();
        vm.warp(block.timestamp + 1);

        string memory image0 = mintRaffle.uri(0);

        /// Input Zero
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert(InputZero.selector);
        mintRaffle.setArt(tokenIds);

        tokenIds = new uint256[](1);
        mintRaffle.setArt(tokenIds);

        string memory image1 = mintRaffle.uri(0);

        /// @dev To account for collisions
        while (keccak256(bytes(image0)) == keccak256(bytes(image1))) {
            vm.warp(block.timestamp + 1);
            mintRaffle.setArt(tokenIds);
            image1 = mintRaffle.uri(0);
        }
        assertNotEq(image0, image1);
    }

    function testSetDescription() public prank(owner) {
        assertEq(
            mintRaffle.description(),
            "Bit98 is a fully on-chain pixel art collection by filter8.eth. Inspired by the color aesthetics of Windows 98, the collection features a novel minting and gamification mechanism, with a new Bit98 generated every 4 hours. At the end of the minting period, a single-edition NFT will be raffled off to one of the minters. Only 512 Bit98s will ever exist! Mint at https://www.basedbits.fun"
        );
        bytes memory newDescription = "ARTY ART";
        mintRaffle.setDescription(newDescription);
        assertEq(mintRaffle.description(), newDescription);
    }

    /// ERC1155SUPPLY ///

    function testERC1155SupplyTransfer() public prank(owner) {
        assertEq(mintRaffle.totalBalanceOf(owner), 1);

        mintRaffle.mint{value: 1e18}();
        assertEq(mintRaffle.totalBalanceOf(owner), 2);
        assertEq(mintRaffle.totalBalanceOf(user0), 1);

        mintRaffle.safeTransferFrom(owner, user0, 2, 1, "");

        assertEq(mintRaffle.totalBalanceOf(owner), 1);
        assertEq(mintRaffle.totalBalanceOf(user0), 2);
    }

    function testERC1155SupplyTransferBatch() public prank(owner) {
        assertEq(mintRaffle.totalBalanceOf(owner), 1);

        mintRaffle.mint{value: 0.1e18}();

        /// mint 1
        vm.warp(block.timestamp + 1.01 days);
        mintRaffle.mint{value: 0.1e18}();
        /// winner and rewarded

        assertEq(mintRaffle.totalBalanceOf(owner), 4);
        assertEq(mintRaffle.totalBalanceOf(user0), 1);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 2;
        ids[1] = 3;
        ids[2] = 4;

        uint256[] memory values = new uint256[](3);
        values[0] = 2;
        values[1] = 1;
        values[2] = 1;

        mintRaffle.safeBatchTransferFrom(owner, user0, ids, values, "");

        assertEq(mintRaffle.totalBalanceOf(owner), 0);
        assertEq(mintRaffle.totalBalanceOf(user0), 5);
    }

    /// ART ///

    function testDraw() public view {
        string memory image = mintRaffle.uri(1);
        image;
        console.log(image);
    }

    function addArt() internal override prank(owner) {
        /// Load some art
        IBBMintRaffleNFT.NamedBytes[] memory placeholder = new IBBMintRaffleNFT.NamedBytes[](1);
        /// Background
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: "AAAe"
        });
        mintRaffle.addArt(0, placeholder);
        /// Face
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: "CCCe"
        });
        mintRaffle.addArt(1, placeholder);
        /// Hair
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: "DDDe"
        });
        mintRaffle.addArt(2, placeholder);
        /// Eyes
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: "FFFe"
        });
        mintRaffle.addArt(3, placeholder);
        /// Mouth
        placeholder[0] = IBBMintRaffleNFT.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: "HHHe"
        });
        mintRaffle.addArt(4, placeholder);
    }
}
