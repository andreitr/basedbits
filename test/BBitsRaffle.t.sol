// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils,
    BBitsCheckIn,
    BBitsRaffle,
    console
} from "./utils/BBitsTestUtils.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IBBitsRaffle} from "../src/interfaces/IBBitsRaffle.sol";

contract BBitsRaffleTest is BBitsTestUtils, IBBitsRaffle {
    function setUp() public override {
        uint256 baseFork = vm.createFork("https://1rpc.io/base");
        vm.selectFork(baseFork);

        owner = 0x1d671d1B191323A38490972D58354971E5c1cd2A;
        /// @dev Use this to access owner token Ids to allow for easy test updating
        ownerTokenIds = [159, 215, 432, 438, 6161];

        user0 = address(100);
        user1 = address(200);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        raffle = new BBitsRaffle(owner, basedBits, checkIn);

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
        assertEq(raffle.raffleCount(), 1);
        assertEq(raffle.rafflePeriod(), 1 days);
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
        uint256 antiBotFee = raffle.antiBotFee();
        raffle.setRandomSeed{value: antiBotFee}();

        vm.expectRevert(IBBitsRaffle.WrongStatus.selector);
        raffle.startNextRaffle();
    }

    function testStartNextRaffleNoTokensToRaffleFailureConditions() public prank(owner) {
        vm.expectRevert(IBBitsRaffle.NoBasedBitsToRaffle.selector);
        raffle.startNextRaffle();
    }

    function testStartNextRaffleSuccessConditions() public prank(owner) {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        raffle.depositBasedBits(tokenIds);
        
        /// @dev the entries array isn't returned
        (
            uint256 startedAt, 
            uint256 settledAt, 
            address winner, 
            IBBitsRaffle.SponsoredPrize memory prize
        ) = raffle.idToRaffle(1);
        uint256 numberOfEntries = raffle.getRaffleEntryNumber(1);

        assertEq(raffle.raffleCount(), 1);
        assertEq(raffle.getCurrentRaffleId(), 0);
        assertEq(startedAt, 0);
        assertEq(settledAt, 0);
        assertEq(winner, address(0));
        assertEq(prize.sponsor, address(0));
        assertEq(prize.tokenId, 0);
        assertEq(numberOfEntries, 0);
        assert(raffle.status() == RaffleStatus.PendingRaffle);

        vm.expectEmit(true, true, true, true);
        emit NewRaffleStarted(1);
        raffle.startNextRaffle();

        (
            startedAt, 
            settledAt, 
            winner, 
            prize
        ) = raffle.idToRaffle(1);
        numberOfEntries = raffle.getRaffleEntryNumber(1);

        assertEq(raffle.raffleCount(), 2);
        assertEq(raffle.getCurrentRaffleId(), 1);
        assertEq(startedAt, block.timestamp);
        assertEq(settledAt, 0);
        assertEq(winner, address(0));
        assertEq(prize.sponsor, owner);
        assertEq(prize.tokenId, ownerTokenIds[2]);
        assertEq(numberOfEntries, 0);
        assert(raffle.status() == RaffleStatus.InRaffle);
    }

    /// ENTRIES ///

    function testNewFreeEntryNotEligibleFailureConditions() public prank(owner) {
        setRaffleStatus(RaffleStatus.InRaffle);
        vm.stopPrank();

        /// Non-owner
        vm.startPrank(user1);
        vm.expectRevert(IBBitsRaffle.NotEligibleForFreeEntry.selector);
        raffle.newFreeEntry(ownerTokenIds[4]);
        vm.stopPrank();

        /// Has not checked in recently
        vm.startPrank(user0);
        vm.expectRevert(IBBitsRaffle.NotEligibleForFreeEntry.selector);
        raffle.newFreeEntry(ownerTokenIds[4]);

        /// Token Already used for free entry
        checkIn.checkIn();
        raffle.newFreeEntry(ownerTokenIds[4]);

        vm.expectRevert(IBBitsRaffle.NotEligibleForFreeEntry.selector);
        raffle.newFreeEntry(ownerTokenIds[4]);
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

        /// PendingSettlement
        setRaffleStatus(RaffleStatus.PendingSettlement);
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

        raffle.newPaidEntry{value: antiBotFee}();

        vm.expectRevert(IBBitsRaffle.AlreadyEnteredRaffle.selector);
        raffle.newPaidEntry{value: antiBotFee}();
    }
}