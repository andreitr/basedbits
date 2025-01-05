// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, RunningGame} from "@test/utils/BBitsTestUtils.sol";
import {IRunningGame} from "@src/interfaces/IRunningGame.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract RunningGameTest -vvv

/// Emit events
contract RunningGameTest is BBitsTestUtils, IRunningGame {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 100e18);
        vm.deal(user0, 100e18);
        vm.deal(user1, 100e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        runningGame = new RunningGame(owner, address(burner));
        //addArt();
    }

    /// SETUP ///

    function testInit() public view {
        assertEq(runningGame.name(), "Running Game");
        assertEq(runningGame.symbol(), "RG");
        assertEq(runningGame.owner(), owner);
        assertEq(address(runningGame.burner()), address(burner));
        assertEq(runningGame.mintingTime(), 22.5 hours);
        assertEq(runningGame.lapTime(), 10 minutes);
        assertEq(runningGame.lapTotal(), 6);
        assertEq(runningGame.burnPercentage(), 2000);
        assertEq(runningGame.totalSupply(), 0);
        assertEq(runningGame.mintFee(), 0.001 ether);
        assertEq(runningGame.raceCount(), 0);
        assertEq(runningGame.lapCount(), 0);
        assert(runningGame.status() == GameStatus.Pending);
    }

    /// MINT ///

    function testMintRevertConditions() public prank(owner) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        runningGame.mint{value: 0.001 ether}();

        /// Insufficient ETH paid
        runningGame.startGame();

        vm.expectRevert(InsufficientETHPaid.selector);
        runningGame.mint();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        runningGame.mint{value: 0.001 ether}();
    }

    function testMintSuccessConditions() public prank(owner) {
        runningGame.startGame();

        uint256 mintFee = runningGame.mintFee();

        (uint256 entries,,,, uint256 prize,) = runningGame.getRace(1);
        assertEq(address(runningGame).balance, 0);
        assertEq(entries, 0);
        assertEq(prize, address(runningGame).balance);

        /// Mint one
        runningGame.mint{value: mintFee}();

        (,,,, prize,) = runningGame.getRace(1);
        assertEq(runningGame.totalSupply(), 1);
        assertEq(runningGame.ownerOf(0), owner);
        assertEq(address(runningGame).balance, (mintFee - (mintFee * runningGame.burnPercentage()) / 10_000));
        assertEq(prize, address(runningGame).balance);

        /// Mint another
        runningGame.mint{value: mintFee}();

        (,,,, prize,) = runningGame.getRace(1);
        assertEq(runningGame.totalSupply(), 2);
        assertEq(runningGame.ownerOf(1), owner);
        assertEq(address(runningGame).balance, 2 * (mintFee - (mintFee * runningGame.burnPercentage()) / 10_000));
        assertEq(prize, address(runningGame).balance);
    }

    /// BOOST ///

    function testBoostRevertConditions() public prank(owner) {
        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        runningGame.boost(0);

        /// Not NFT owner
        runningGame.startGame();
        runningGame.mint{value: runningGame.mintFee()}();
        runningGame.mint{value: runningGame.mintFee()}();
        runningGame.transferFrom(owner, user0, 0);

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.expectRevert(NotNFTOwner.selector);
        runningGame.boost(0);

        /// Has already boosted this lap
        runningGame.boost(1);

        vm.expectRevert(HasBoosted.selector);
        runningGame.boost(1);

        /// Invalid Node
        vm.expectRevert();
        runningGame.boost(2);

        /// @dev finish this game and start another
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.finishGame();
        runningGame.startGame();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.expectRevert(InvalidNode.selector);
        runningGame.boost(1);
    }

    function testBoostSuccessConditions() public prank(owner) {
        runningGame.startGame();
        runningGame.mint{value: runningGame.mintFee()}();
        runningGame.mint{value: runningGame.mintFee()}();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        /// Get position and hasBoosted before
        (,, uint256[] memory positions) = runningGame.getLap(1, 0);
        bool hasBoosted = runningGame.getHasBoosted(1, 1, 1);
        assertEq(positions[0], 0);
        assertEq(positions[1], 1);
        assertEq(hasBoosted, false);

        /// Boost
        runningGame.boost(1);

        /// Note that the positions arrays are only updated at the end of each lap
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        (,, positions) = runningGame.getLap(1, 1);
        hasBoosted = runningGame.getHasBoosted(1, 1, 1);
        assertEq(positions[0], 1);
        assertEq(positions[1], 0);
        assertEq(hasBoosted, true);
    }

    /// START GAME ///

    function testStartGameRevertConditions() public prank(owner) {
        runningGame.startGame();

        /// Wrong status - InMint
        vm.expectRevert(WrongStatus.selector);
        runningGame.startGame();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        runningGame.startGame();
    }

    function testStartGameSuccessConditions() public prank(owner) {
        (, uint256 startedAt,,,,) = runningGame.getRace(1);
        assertEq(startedAt, 0);
        assert(runningGame.status() == GameStatus.Pending);

        runningGame.startGame();

        (, startedAt,,,,) = runningGame.getRace(1);
        assertEq(startedAt, block.timestamp);
        assert(runningGame.status() == GameStatus.InMint);
    }

    /// START NEXT LAP ///

    function testStartNextLapRevertConditions() public prank(owner) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        runningGame.startNextLap();

        /// Minting still active
        runningGame.startGame();

        vm.expectRevert(MintingStillActive.selector);
        runningGame.startNextLap();

        /// Lap still active
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.expectRevert(LapStillActive.selector);
        runningGame.startNextLap();

        /// Final lap
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        vm.warp(block.timestamp + 1.01 days);

        vm.expectRevert(IsFinalLap.selector);
        runningGame.startNextLap();
    }

    function testStartNextLapSuccessConditions() public prank(owner) {
        runningGame.startGame();
        vm.warp(block.timestamp + 1.01 days);

        /// First lap
        assert(runningGame.status() == GameStatus.InMint);
        assertEq(runningGame.lapCount(), 0);
        (uint256 startedAt, uint256 endedAt, uint256[] memory positions) = runningGame.getLap(1, 1);
        assertEq(startedAt, 0);
        assertEq(endedAt, 0);
        assertEq(positions.length, 0);

        runningGame.startNextLap();

        assert(runningGame.status() == GameStatus.InRace);
        assertEq(runningGame.lapCount(), 1);
        (startedAt, endedAt, positions) = runningGame.getLap(1, 1);
        assertEq(startedAt, block.timestamp);
        assertEq(endedAt, 0);
        assertEq(positions.length, 0);

        /// Second lap
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        assertEq(runningGame.lapCount(), 2);
        (startedAt, endedAt, positions) = runningGame.getLap(1, 1);
        assertEq(startedAt, block.timestamp - 1.01 days);
        assertEq(endedAt, block.timestamp);
        assertEq(positions.length, 0);
    }

    function testEliminateRunners() public prank(owner) {
        runningGame.startGame();

        /// Mint 7 so that a runner is eliminated each lap
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();

        /// Lap 1
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        (uint256 entries,,,,,) = runningGame.getRace(1);
        assertEq(entries, 7);
        (,, uint256[] memory positions) = runningGame.getLap(1, 0);
        assertEq(positions.length, 7);

        /// Lap 2
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        (,, positions) = runningGame.getLap(1, 1);
        assertEq(positions.length, 6);

        /// Lap 3
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        (,, positions) = runningGame.getLap(1, 2);
        assertEq(positions.length, 5);

        /// Lap 4
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        (,, positions) = runningGame.getLap(1, 3);
        assertEq(positions.length, 4);

        /// Lap 5
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        (,, positions) = runningGame.getLap(1, 4);
        assertEq(positions.length, 3);

        /// Lap 6
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();
        (,, positions) = runningGame.getLap(1, 5);
        assertEq(positions.length, 2);
    }

    /// FINISH GAME ///

    /*
    function testFullGame() public prank(owner) {
        runningGame.startGame();

        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.finishGame();
        
        /// Second race
        runningGame.startGame();

        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();
        runningGame.mint{value: 0.001 ether}();

        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        runningGame.boost(8);
    }
    */

    /// SETTINGS ///

    /// ART ///
}
