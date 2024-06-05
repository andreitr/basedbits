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

        /// @dev Owner of Based Bits, some tokenIds: 159, 215, 432, 438, 6161
        owner = 0x1d671d1B191323A38490972D58354971E5c1cd2A;

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        raffle = new BBitsRaffle(owner, basedBits, checkIn);

        vm.prank(owner);
        basedBits.setApprovalForAll(address(raffle), true);
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
        tokenIds[0] = 159;

        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, 159);
        raffle.depositBasedBits(tokenIds);

        (uint256 _tokenId, address _sponsor) = raffle.prizes(0);
        assertEq(_tokenId, 159);
        assertEq(_sponsor, owner);

        /// Deposit multiple
        tokenIds = new uint256[](3);
        tokenIds[0] = 432;
        tokenIds[1] = 215;
        tokenIds[2] = 438;

        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, 432);
        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, 215);
        vm.expectEmit(true, true, true, true);
        emit BasedBitsDeposited(owner, 438);
        raffle.depositBasedBits(tokenIds);

        (_tokenId, _sponsor) = raffle.prizes(0);
        assertEq(_tokenId, 159);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(1);
        assertEq(_tokenId, 432);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(2);
        assertEq(_tokenId, 215);
        assertEq(_sponsor, owner);

        (_tokenId, _sponsor) = raffle.prizes(3);
        assertEq(_tokenId, 438);
        assertEq(_sponsor, owner);
    }
}