// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsCheckIn, BBitsRaffle, console} from "@test/utils/BBitsTestUtils.sol";
import {ERC721, IERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IBBitsRaffle} from "@src/interfaces/IBBitsRaffle.sol";
import {MockBrokenSettleRafflePOC, Brick} from "@test/mocks/MockBrokenSettleRafflePOC.sol";

contract BBitsRaffleTest is BBitsTestUtils, IBBitsRaffle {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        raffle = new BBitsRaffle(owner, basedBits, checkIn);

        unpauseLegacyCheckin();

        /// @dev Ancillary test setup:
        ///      Owner approvals raffle for all tokens
        ///      User0 given one token
        vm.startPrank(owner);
        basedBits.setApprovalForAll(address(raffle), true);
        basedBits.transferFrom(owner, user0, ownerTokenIds[4]);
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(address(raffle.collection()), address(basedBits));
        assertEq(address(raffle.checkIn()), address(checkIn));
        assertEq(raffle.count(), 1);
        assertEq(raffle.duration(), 1 days);
        assertEq(raffle.antiBotFee(), 0.0001 ether);
        assertEq(raffle.paused(), false);
        assertEq(raffle.owner(), owner);
        assert(raffle.status() == RaffleStatus.PendingRaffle);
    }

    /// DEPOSIT ///

    function testDepositBasedBitsFailureConditions() public {
        /// Deposit zero
        uint256[] memory tokenIds = new uint256[](0);
        vm.expectRevert(IBBitsRaffle.DepositZero.selector);
        raffle.depositBasedBits(tokenIds);

        /// Non-owner
        tokenIds = new uint256[](1);
        vm.expectRevert();
        raffle.depositBasedBits(tokenIds);
    }

    function testDepositBasedBitsSuccess() public prank(owner) {
        /// Deposit single
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];

        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, ownerTokenIds[0]);
        raffle.depositBasedBits(tokenIds);

        (uint256 _tokenId, address _sponsor) = raffle.prizes(0);
        assertEq(_tokenId, ownerTokenIds[0]);
        assertEq(_sponsor, owner);

        /// Deposit multiple
        tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[1];
        tokenIds[1] = ownerTokenIds[2];
        tokenIds[2] = ownerTokenIds[3];

        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, ownerTokenIds[1]);
        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, ownerTokenIds[2]);
        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, ownerTokenIds[3]);
        raffle.depositBasedBits(tokenIds);

        (_tokenId, _sponsor) = raffle.prizes(0);
        assertEq(_tokenId, ownerTokenIds[0]);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(1);
        assertEq(_tokenId, ownerTokenIds[1]);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(2);
        assertEq(_tokenId, ownerTokenIds[2]);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(3);
        assertEq(_tokenId, ownerTokenIds[3]);
        assertEq(_sponsor, owner);
    }

    /// START RAFFLE ///

    function testStartNextRaffleWrongStatusFailureConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.expectRevert(IBBitsRaffle.WrongStatus.selector);
        raffle.startNextRaffle();

        vm.warp(block.timestamp + 1.01 days);

        vm.expectRevert(IBBitsRaffle.WrongStatus.selector);
        raffle.startNextRaffle();
    }

    function testStartNextRaffleNoTokensToRaffleFailureConditions() public prank(owner) {
        /// No prizes ever
        vm.expectRevert(IBBitsRaffle.NoBasedBitsToRaffle.selector);
        raffle.startNextRaffle();

        /// Prizes run out
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();

        uint256 antiBotFee = raffle.antiBotFee();
        raffle.newPaidEntry{value: antiBotFee}();

        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 10);
        raffle.settleRaffle();

        vm.expectRevert(IBBitsRaffle.NoBasedBitsToRaffle.selector);
        raffle.startNextRaffle();

        /// Open again
        tokenIds[0] = ownerTokenIds[1];
        raffle.depositBasedBits(tokenIds);

        vm.expectEmit(true, true, true, true);
        emit NewRaffleStarted(2);
        raffle.startNextRaffle();
    }

    function testStartNextRaffleSuccessConditions() public prank(owner) {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        raffle.depositBasedBits(tokenIds);

        /// @dev the entries array isn't returned
        (uint256 startedAt, uint256 settledAt, address winner, IBBitsRaffle.SponsoredPrize memory prize) =
            raffle.idToRaffle(1);
        uint256 numberOfEntries = raffle.getRaffleEntryNumber(1);

        assertEq(raffle.count(), 1);
        assertEq(raffle.getCurrentRaffleId(), 0);
        assertEq(startedAt, 0);
        assertEq(settledAt, 0);
        assertEq(winner, address(0));
        assertEq(prize.sponsor, address(0));
        assertEq(prize.tokenId, 0);
        assertEq(numberOfEntries, 0);
        assert(raffle.status() == RaffleStatus.PendingRaffle);
        //uint256

        vm.expectEmit(true, true, true, true);
        emit NewRaffleStarted(1);
        raffle.startNextRaffle();

        (startedAt, settledAt, winner, prize) = raffle.idToRaffle(1);
        numberOfEntries = raffle.getRaffleEntryNumber(1);

        assertEq(raffle.count(), 2);
        assertEq(raffle.getCurrentRaffleId(), 1);
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);
        assertEq(winner, address(0));
        assertEq(prize.sponsor, owner);
        assertEq(prize.tokenId, ownerTokenIds[0]);
        assertEq(numberOfEntries, 0);
        assert(raffle.status() == RaffleStatus.InRaffle);
    }

    /// ENTRIES ///

    function testGetRaffleEntryByIndexFailureConditions() public {
        vm.startPrank(owner);
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.stopPrank();

        vm.expectRevert(IBBitsRaffle.IndexOutOfBounds.selector);
        raffle.getRaffleEntryByIndex(1, 10);
    }

    function testNewFreeEntryNotEligibleFailureConditions() public {
        vm.startPrank(owner);
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.stopPrank();

        bool query;

        /// Non-owner
        vm.startPrank(user1);
        query = raffle.isEligibleForFreeEntry(user1);
        assertEq(query, false);
        vm.expectRevert(IBBitsRaffle.NotEligibleForFreeEntry.selector);
        raffle.newFreeEntry();
        vm.stopPrank();

        /// Has not checked in recently
        vm.startPrank(user0);
        query = raffle.isEligibleForFreeEntry(user0);
        assertEq(query, false);
        vm.expectRevert(IBBitsRaffle.NotEligibleForFreeEntry.selector);
        raffle.newFreeEntry();

        checkIn.checkIn();
        query = raffle.isEligibleForFreeEntry(user0);
        assertEq(query, true);
    }

    function testNewPaidEntryMustPayAntiBotFeeFailureConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);

        vm.expectRevert(IBBitsRaffle.MustPayAntiBotFee.selector);
        raffle.newPaidEntry();
    }

    function testNewEntryWrongStatusFailureConditions() public prank(owner) {
        uint256 antiBotFee = raffle.antiBotFee();

        /// PendingRaffle
        vm.expectRevert(IBBitsRaffle.WrongStatus.selector);
        raffle.newPaidEntry{value: antiBotFee}();
    }

    function testNewEntryRaffleExpiredFailureConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        uint256 antiBotFee = raffle.antiBotFee();

        vm.warp(block.timestamp + 1.01 days);

        vm.expectRevert(IBBitsRaffle.RaffleExpired.selector);
        raffle.newPaidEntry{value: antiBotFee}();
    }

    function testNewEntryAlreadyEnteredRaffleFailureConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        uint256 antiBotFee = raffle.antiBotFee();

        assertEq(raffle.hasEnteredRaffle(1, owner), false);

        raffle.newPaidEntry{value: antiBotFee}();

        assertEq(raffle.hasEnteredRaffle(1, owner), true);

        vm.expectRevert(IBBitsRaffle.AlreadyEnteredRaffle.selector);
        raffle.newPaidEntry{value: antiBotFee}();
    }

    function testNewFreeEntrySuccessConditions() public prank(owner) {
        uint256 timestamp = vm.getBlockTimestamp();
        vm.warp(timestamp += 1.01 days);
        checkIn.checkIn();
        vm.warp(timestamp += 1.01 days);
        setRaffleStatus(RaffleStatus.InRaffle);
        checkIn.checkIn();

        assertEq(raffle.hasEnteredRaffle(1, owner), false);
        assertEq(raffle.getRaffleEntryNumber(1), 0);

        vm.expectEmit(true, true, true, true);
        emit RaffleEntered(1, owner);
        raffle.newFreeEntry();

        assertEq(raffle.hasEnteredRaffle(1, owner), true);
        assertEq(raffle.getRaffleEntryNumber(1), 1);
        assertEq(raffle.getRaffleEntryByIndex(1, 0), owner);
    }

    function testNewPaidEntrySuccessConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        uint256 antiBotFee = raffle.antiBotFee();
        uint256 raffleBalanceBefore = address(raffle).balance;

        assertEq(raffle.hasEnteredRaffle(1, owner), false);
        assertEq(raffle.getRaffleEntryNumber(1), 0);

        vm.expectEmit(true, true, true, true);
        emit RaffleEntered(1, owner);
        raffle.newPaidEntry{value: antiBotFee}();

        assertEq(raffle.hasEnteredRaffle(1, owner), true);
        assertEq(raffle.getRaffleEntryNumber(1), 1);
        assertEq(raffle.getRaffleEntryByIndex(1, 0), owner);
        assertEq(address(raffle).balance, raffleBalanceBefore + antiBotFee);
    }

    /// SETTLE RAFFLE ///

    function testSettleRaffleWrongStatusFailureConditions() public prank(owner) {
        /// Pending Raffle
        vm.expectRevert(IBBitsRaffle.WrongStatus.selector);
        raffle.settleRaffle();

        /// In Raffle
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.expectRevert(IBBitsRaffle.RaffleOnGoing.selector);
        raffle.settleRaffle();
    }

    function testSettleRaffleNoEntriesSuccessConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 2);

        assertEq(basedBits.balanceOf(address(raffle)), 3);

        vm.expectEmit(true, true, true, true);
        emit RaffleSettled(1, address(0), 0);
        raffle.settleRaffle();

        (, uint256 settledAt, address winner,) = raffle.idToRaffle(1);
        (uint256 tokenId, address sponsor) = raffle.prizes(2);

        assertEq(raffle.getRaffleEntryNumber(1), 0);
        assertEq(settledAt, block.timestamp);
        assertEq(winner, address(0));
        assert(raffle.status() == RaffleStatus.InRaffle);
        assertEq(basedBits.balanceOf(address(raffle)), 3);
        assertEq(tokenId, ownerTokenIds[2]);
        assertEq(sponsor, owner);
    }

    function testSettleRaffleOneEntrySuccessConditions() public prank(owner) {
        setRaffleInMotionWithOnePaidEntry();

        uint256 antiBotFee = raffle.antiBotFee();
        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 2);

        assertEq(basedBits.balanceOf(address(raffle)), 3);
        assertEq(address(raffle).balance, antiBotFee);
        uint256 ownerBalanceBefore = owner.balance;

        /// Settle
        /// @dev Owner is both winner and sponsor
        vm.expectEmit(true, true, true, true);
        emit RaffleSettled(1, owner, ownerTokenIds[0]);
        raffle.settleRaffle();

        (, uint256 settledAt, address winner,) = raffle.idToRaffle(1);
        (uint256 tokenId, address sponsor) = raffle.prizes(0);

        assertEq(raffle.getRaffleEntryNumber(1), 1);
        assertEq(settledAt, block.timestamp);
        assertEq(winner, owner);
        assert(raffle.status() == RaffleStatus.InRaffle);
        assertEq(basedBits.balanceOf(address(raffle)), 2);
        assertEq(tokenId, ownerTokenIds[2]);
        assertEq(sponsor, owner);
        assertEq(address(raffle).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + antiBotFee);
        assertEq(basedBits.ownerOf(ownerTokenIds[0]), owner);
    }

    function testSettleRaffleMultipleEntriesSuccessConditions() public prank(owner) {
        setRaffleInMotionWithOnePaidEntry();
        uint256 antiBotFee = raffle.antiBotFee();

        /// User0 enters
        vm.stopPrank();
        vm.startPrank(user0);
        raffle.newPaidEntry{value: antiBotFee}();

        assertEq(basedBits.balanceOf(address(raffle)), 3);
        assertEq(address(raffle).balance, 2 * antiBotFee);
        uint256 ownerBalanceBefore = owner.balance;
        uint256 user0BalanceBefore = user0.balance;

        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 2);

        /// Settle
        /// @dev Get random number given that it is the seed block
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(user0, blockhash(block.number - 1))));
        assertNotEq(blockhash(block.number - 1), bytes32(0));
        uint256 winningIndex = pseudoRandom % 2;
        address predictedWinner = raffle.getRaffleEntryByIndex(1, winningIndex);

        vm.expectEmit(true, true, true, true);
        emit RaffleSettled(1, predictedWinner, ownerTokenIds[0]);
        raffle.settleRaffle();

        (, uint256 settledAt, address winner,) = raffle.idToRaffle(1);
        (uint256 tokenId, address sponsor) = raffle.prizes(0);

        assertEq(raffle.getRaffleEntryNumber(1), 2);
        assertEq(settledAt, block.timestamp);
        assertEq(winner, predictedWinner);
        assert(raffle.status() == RaffleStatus.InRaffle);
        assertEq(basedBits.balanceOf(address(raffle)), 2);
        assertEq(tokenId, ownerTokenIds[2]);
        assertEq(sponsor, owner);
        assertEq(address(raffle).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + (2 * antiBotFee));
        assertEq(user0.balance, user0BalanceBefore);
        assertEq(basedBits.ownerOf(ownerTokenIds[0]), predictedWinner);

        vm.stopPrank();
    }

    function testSettleRaffleNewRaffleInitiated() public prank(owner) {
        /// One prize, no entries
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();

        assert(raffle.status() == RaffleStatus.InRaffle);

        vm.warp(block.timestamp + 1.01 days);

        raffle.settleRaffle();

        /// Raffle reset
        assert(raffle.status() == RaffleStatus.InRaffle);

        (, uint256 settledAt, address winner,) = raffle.idToRaffle(1);
        (uint256 tokenId, address sponsor) = raffle.prizes(0);

        assertEq(settledAt, block.timestamp);
        assertEq(winner, address(0));
        assertEq(tokenId, ownerTokenIds[0]);
        assertEq(sponsor, owner);

        /// One winner, no prizes left, raffle back to pending raffle stage
        uint256 antiBotFee = raffle.antiBotFee();
        raffle.newPaidEntry{value: antiBotFee}();
        vm.warp(block.timestamp + 1.01 days);

        raffle.settleRaffle();

        assert(raffle.status() == RaffleStatus.PendingRaffle);
        (, settledAt, winner,) = raffle.idToRaffle(2);
        assertEq(settledAt, block.timestamp);
        assertEq(winner, owner);

        vm.expectRevert();
        (tokenId, sponsor) = raffle.prizes(0);
    }

    function testSettleRaffleReturnDepositsMidRaffle() public prank(owner) {
        /// One prize, one entry
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();

        assert(raffle.status() == RaffleStatus.InRaffle);
        vm.warp(block.timestamp + 1.01 days);

        /// Owner returns BB before settlement
        raffle.setPaused(true);
        raffle.returnDeposits();
        raffle.setPaused(false);
        raffle.settleRaffle();

        (, uint256 settledAt, address winner,) = raffle.idToRaffle(1);
        assertEq(settledAt, block.timestamp);
        assertEq(winner, address(0));
        assert(raffle.status() == RaffleStatus.PendingRaffle);
    }

    /// ONLY OWNER ///

    function testSetPaused() public prank(owner) {
        assertEq(raffle.paused(), false);

        raffle.setPaused(true);
        assertEq(raffle.paused(), true);

        raffle.setPaused(false);
        assertEq(raffle.paused(), false);

        /// Non owner
        vm.stopPrank();
        vm.startPrank(user0);

        vm.expectRevert();
        raffle.setPaused(true);

        vm.stopPrank();
    }

    function testSetAntiBotFee() public prank(owner) {
        assertEq(raffle.antiBotFee(), 0.0001 ether);

        raffle.setAntiBotFee(0.1 ether);
        assertEq(raffle.antiBotFee(), 0.1 ether);

        /// Non owner
        vm.stopPrank();
        vm.startPrank(user0);

        vm.expectRevert();
        raffle.setAntiBotFee(1 ether);

        vm.stopPrank();
    }

    function testSetDuration() public prank(owner) {
        assertEq(raffle.duration(), 1 days);

        raffle.setDuration(7 days);
        assertEq(raffle.duration(), 7 days);

        /// Non owner
        vm.stopPrank();
        vm.startPrank(user0);

        vm.expectRevert();
        raffle.setDuration(2 days);

        vm.stopPrank();
    }

    function testReturnDepositsAdditionalFailureConditions() public prank(owner) {
        /// No deposits
        raffle.setPaused(true);
        vm.expectRevert(DepositZero.selector);
        raffle.returnDeposits();

        /// Non-owner
        vm.stopPrank();
        vm.startPrank(user0);
        vm.expectRevert();
        raffle.returnDeposits();

        /// No deposits after settlement
        vm.stopPrank();
        vm.startPrank(owner);
        raffle.setPaused(false);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();

        uint256 antiBotFee = raffle.antiBotFee();
        raffle.newPaidEntry{value: antiBotFee}();

        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 2);
        raffle.settleRaffle();

        raffle.setPaused(true);
        vm.expectRevert(DepositZero.selector);
        raffle.returnDeposits();
    }

    function testReturnDepositsSuccessConditions() public prank(owner) {
        /// 1 deposit
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = ownerTokenIds[0];
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();

        vm.warp(block.timestamp + 1.01 days);
        vm.roll(block.number + 2);
        raffle.settleRaffle();
        raffle.setPaused(true);

        (uint256 _tokenId, address _sponsor) = raffle.prizes(0);
        assertEq(basedBits.ownerOf(_tokenId), address(raffle));
        assertEq(basedBits.balanceOf(address(raffle)), 1);

        raffle.returnDeposits();

        assertEq(basedBits.ownerOf(_tokenId), _sponsor);
        assertEq(basedBits.balanceOf(address(raffle)), 0);
    }

    /// PAUSED ///

    function testWhenNotPaused() public prank(owner) {
        raffle.setPaused(true);

        uint256[] memory tokenIds = new uint256[](0);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.depositBasedBits(tokenIds);

        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.startNextRaffle();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.newFreeEntry();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.newPaidEntry{value: 0.0001 ether}();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        raffle.settleRaffle();
    }

    function testWhenPaused() public prank(owner) {
        vm.expectRevert(Pausable.ExpectedPause.selector);
        raffle.returnDeposits();
    }

    /// MISC ///

    function testCanBrickRaffleLoopWithCallResponseCheck() public prank(owner) {
        /// Setup
        MockBrokenSettleRafflePOC mock = new MockBrokenSettleRafflePOC(basedBits);
        Brick brick = new Brick(basedBits, mock);
        (bool s,) = address(mock).call{value: 0.1 ether}("");
        assert(s);

        /// The Attack
        basedBits.transferFrom(owner, address(brick), ownerTokenIds[3]);
        brick.CallDepositBasedBitsMock(ownerTokenIds[3]);
        vm.expectRevert(IBBitsRaffle.TransferFailed.selector);
        mock.settleRaffleMock();

        assertEq(mock.reset(), false);
    }
}
