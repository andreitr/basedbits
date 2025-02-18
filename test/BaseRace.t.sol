// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, BaseRace} from "@test/utils/BBitsTestUtils.sol";
import {IBaseRace} from "@src/interfaces/IBaseRace.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract BaseRaceTest -vvv
contract BaseRaceTest is BBitsTestUtils, IBaseRace {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public admin;

    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);
        admin = makeAddr("ADMIN");

        vm.deal(owner, 100e18);
        vm.deal(admin, 100e18);
        vm.deal(user0, 100e18);
        vm.deal(user1, 100e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        baseRace = new BaseRace(owner, admin, address(burner));
        //addArt();
    }

    /// SETUP ///

    function testInit() public view {
        assertEq(baseRace.name(), "Base Race");
        assertEq(baseRace.symbol(), "BRCE");
        assertEq(baseRace.hasRole(DEFAULT_ADMIN_ROLE, owner), true);
        assertEq(baseRace.hasRole(ADMIN_ROLE, admin), true);
        assertEq(address(baseRace.burner()), address(burner));
        assertEq(baseRace.mintingTime(), 22.5 hours);
        assertEq(baseRace.lapTime(), 10 minutes);
        assertEq(baseRace.lapTotal(), 6);
        assertEq(baseRace.burnPercentage(), 2000);
        assertEq(baseRace.totalSupply(), 0);
        assertEq(baseRace.mintFee(), 0.001 ether);
        assertEq(baseRace.raceCount(), 0);
        //assertEq(baseRace.lapCount(), 0);
        assert(baseRace.status() == GameStatus.Pending);
    }

    /// MINT ///

    function testMintRevertConditions() public prank(admin) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        baseRace.mint{value: 0.001 ether}();

        /// Insufficient ETH paid
        baseRace.startGame();

        vm.expectRevert(InsufficientETHPaid.selector);
        baseRace.mint();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        baseRace.mint{value: 0.001 ether}();
    }

    function testMintSuccessConditions() public prank(admin) {
        baseRace.startGame();

        uint256 mintFee = baseRace.mintFee();

        (uint256 entries,,,, uint256 prize,) = baseRace.getRace(1);
        assertEq(address(baseRace).balance, 0);
        assertEq(entries, 0);
        assertEq(prize, address(baseRace).balance);

        /// Mint one
        baseRace.mint{value: mintFee}();

        (,,,, prize,) = baseRace.getRace(1);
        assertEq(baseRace.totalSupply(), 1);
        assertEq(baseRace.ownerOf(0), admin);
        assertEq(address(baseRace).balance, (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));
        assertEq(prize, address(baseRace).balance);

        /// Mint another
        baseRace.mint{value: mintFee}();

        (,,,, prize,) = baseRace.getRace(1);
        assertEq(baseRace.totalSupply(), 2);
        assertEq(baseRace.ownerOf(1), admin);
        assertEq(address(baseRace).balance, 2 * (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));
        assertEq(prize, address(baseRace).balance);
    }

    /// BOOST ///

    function testBoostRevertConditions() public prank(admin) {
        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        baseRace.boost(0);

        /// Not NFT owner
        baseRace.startGame();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.transferFrom(admin, user0, 0);

        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(NotNFTOwner.selector);
        baseRace.boost(0);

        /// Has already boosted this lap
        baseRace.boost(1);

        vm.expectRevert(HasBoosted.selector);
        baseRace.boost(1);

        /// Invalid Node
        vm.expectRevert();
        baseRace.boost(2);

        /// @dev finish this game and start another
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.finishGame();
        baseRace.startGame();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(InvalidNode.selector);
        baseRace.boost(1);
    }

    function testBoostSuccessConditions() public prank(admin) {
        baseRace.startGame();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        /// Get position and hasBoosted before
        (,, uint256[] memory positionsA) = baseRace.getLap(1, 1);
        bool hasBoosted = baseRace.isBoosted(1, 1, 1);
        assertEq(hasBoosted, false);

        /// Boost
        baseRace.boost(1);

        (,, uint256[] memory positionsB) = baseRace.getLap(1, 1);
        hasBoosted = baseRace.isBoosted(1, 1, 1);
        assertEq(positionsA[0], positionsB[1]);
        assertEq(hasBoosted, true);
    }

    /// START GAME ///

    function testStartGameRevertConditions() public prank(admin) {
        baseRace.startGame();

        /// Wrong status - InMint
        vm.expectRevert(WrongStatus.selector);
        baseRace.startGame();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        baseRace.startGame();
    }

    function testStartGameSuccessConditions() public prank(admin) {
        (, uint256 startedAt,,,,) = baseRace.getRace(1);
        assertEq(startedAt, 0);
        assert(baseRace.status() == GameStatus.Pending);

        vm.expectEmit(true, true, true, true);
        emit GameStarted(1, block.timestamp);
        baseRace.startGame();

        (, startedAt,,,,) = baseRace.getRace(1);
        assertEq(startedAt, block.timestamp);
        assert(baseRace.status() == GameStatus.InMint);
    }

    /// START NEXT LAP ///

    function testStartNextLapRevertConditions() public prank(admin) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        baseRace.startNextLap();

        /// Minting still active
        baseRace.startGame();

        vm.expectRevert(MintingStillActive.selector);
        baseRace.startNextLap();

        /// Lap still active
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(LapStillActive.selector);
        baseRace.startNextLap();

        /// Final lap
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);

        vm.expectRevert(IsFinalLap.selector);
        baseRace.startNextLap();
    }

    function testStartNextLapSuccessConditions() public prank(admin) {
        baseRace.startGame();
        vm.warp(block.timestamp + 1.01 days);

        /// First lap
        assert(baseRace.status() == GameStatus.InMint);
        //assertEq(baseRace.lapCount(), 0);
        (uint256 startedAt, uint256 endedAt, uint256[] memory positions) = baseRace.getLap(1, 1);
        assertEq(startedAt, 0);
        assertEq(endedAt, 0);
        assertEq(positions.length, 0);

        vm.expectEmit(true, true, true, true);
        emit LapStarted(1, 1, block.timestamp);
        baseRace.startNextLap();

        assert(baseRace.status() == GameStatus.InRace);
        //assertEq(baseRace.lapCount(), 1);
        (startedAt, endedAt, positions) = baseRace.getLap(1, 1);
        assertEq(startedAt, block.timestamp);
        assertEq(endedAt, 0);
        assertEq(positions.length, 0);

        /// Second lap
        vm.warp(block.timestamp + 1.01 days);

        vm.expectEmit(true, true, true, true);
        emit LapStarted(1, 2, block.timestamp);
        baseRace.startNextLap();

        //assertEq(baseRace.lapCount(), 2);
        (startedAt, endedAt, positions) = baseRace.getLap(1, 1);
        assertEq(startedAt, block.timestamp - 1.01 days);
        assertEq(endedAt, block.timestamp);
        assertEq(positions.length, 0);
    }

    function testEliminateRunners() public prank(admin) {
        baseRace.startGame();

        /// Mint 7 so that a runner is eliminated each lap
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        /// Lap 1
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        (uint256 entries,,,,,) = baseRace.getRace(1);
        assertEq(entries, 7);
        (,, uint256[] memory positions) = baseRace.getLap(1, 1);
        assertEq(positions.length, 7);

        /// Lap 2
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, positions) = baseRace.getLap(1, 2);
        assertEq(positions.length, 6);

        /// Lap 3
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, positions) = baseRace.getLap(1, 3);
        assertEq(positions.length, 5);

        /// Lap 4
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, positions) = baseRace.getLap(1, 4);
        assertEq(positions.length, 4);

        /// Lap 5
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, positions) = baseRace.getLap(1, 5);
        assertEq(positions.length, 3);

        /// Lap 6
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, positions) = baseRace.getLap(1, 6);
        assertEq(positions.length, 2);
    }

    /// FINISH GAME ///

    function testFinishGameRevertConditions() public prank(admin) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        baseRace.finishGame();

        /// Wrong status - InMint
        baseRace.startGame();

        vm.expectRevert(WrongStatus.selector);
        baseRace.finishGame();

        /// Final lap not reached
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(FinalLapNotReached.selector);
        baseRace.finishGame();

        /// Lap still active
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(LapStillActive.selector);
        baseRace.finishGame();
    }

    function testFinishGameSuccessConditions() public prank(admin) {
        baseRace.startGame();

        baseRace.mint{value: 0.001 ether}();

        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.warp(block.timestamp + 1.01 days);

        uint256 mintFee = baseRace.mintFee();
        uint256 winnerBalanceBefore = admin.balance;
        assertEq(address(baseRace).balance, (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));

        vm.expectEmit(true, true, true, true);
        emit GameEnded(1, block.timestamp);
        baseRace.finishGame();

        assertEq(address(baseRace).balance, 0);
        assertEq(admin.balance, winnerBalanceBefore + (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));
        assert(baseRace.status() == GameStatus.Pending);
    }

    /// SETTINGS ///

    /// ART ///
}
