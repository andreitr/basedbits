// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, BaseRace} from "@test/utils/BBitsTestUtils.sol";
import {IBaseRace} from "@src/interfaces/IBaseRace.sol";
import {ERC721, IERC721Errors} from "@openzeppelin/token/ERC721/ERC721.sol";
import {InvalidPointer} from "@dll/DoublyLinkedList.sol";

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

    function testInitBaseRace() public view {
        assertEq(baseRace.name(), "Base Race");
        assertEq(baseRace.symbol(), "BRCE");
        assertEq(baseRace.hasRole(DEFAULT_ADMIN_ROLE, owner), true);
        assertEq(baseRace.hasRole(ADMIN_ROLE, admin), true);
        assertEq(address(baseRace.burner()), address(burner));
        assertEq(baseRace.mintingTime(), 22.5 hours);
        assertEq(baseRace.lapTime(), 10 minutes);
        assertEq(baseRace.burnPercentage(), 2000);
        assertEq(baseRace.totalSupply(), 0);
        assertEq(baseRace.mintFee(), 0.001 ether);
        assertEq(baseRace.raceCount(), 0);
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

        /// Mint minimum required runners (2) before testing InRace status
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        baseRace.mint{value: 0.001 ether}();
    }

    function testMintSuccessConditions() public prank(admin) {
        baseRace.startGame();

        uint256 mintFee = baseRace.mintFee();

        (uint256 entries,,,,, uint256 prize,) = baseRace.getRace(1);
        assertEq(address(baseRace).balance, 0);
        assertEq(entries, 0);
        assertEq(prize, address(baseRace).balance);

        /// Mint one
        baseRace.mint{value: mintFee}();

        (,,,,, prize,) = baseRace.getRace(1);
        assertEq(baseRace.totalSupply(), 1);
        assertEq(baseRace.ownerOf(0), admin);
        assertEq(address(baseRace).balance, (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));
        assertEq(prize, address(baseRace).balance);

        /// Mint another
        baseRace.mint{value: mintFee}();

        (,,,,, prize,) = baseRace.getRace(1);
        assertEq(baseRace.totalSupply(), 2);
        assertEq(baseRace.ownerOf(1), admin);
        assertEq(address(baseRace).balance, 2 * (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000));
        assertEq(prize, address(baseRace).balance);
    }

    /// DYNAMIC LAP CALCULATION ///

    function testSmallRaceLaps() public prank(admin) {
        baseRace.startGame();

        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        (,,, uint256 lapTotal,,,) = baseRace.getRace(1);
        assertEq(lapTotal, 2);
    }

    function testMediumRaceLaps() public prank(admin) {
        baseRace.startGame();

        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        (,,, uint256 lapTotal,,,) = baseRace.getRace(1);
        assertEq(lapTotal, 5);
    }

    function testLargeRaceLaps() public prank(admin) {
        baseRace.startGame();

        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        (,,, uint256 lapTotal,,,) = baseRace.getRace(1);
        assertEq(lapTotal, 6);
    }

    /// BOOST ///

    function testBoostRevertConditions() public prank(admin) {
        uint256 mintFee = 0.001 ether;

        // Test 1: Cannot boost in Pending state
        vm.expectRevert(WrongStatus.selector);
        baseRace.boost(0);

        // Test 2: Cannot boost in InMint state
        baseRace.startGame();
        baseRace.mint{value: mintFee}();
        baseRace.mint{value: mintFee}(); // Need at least 2 runners
        vm.expectRevert(WrongStatus.selector);
        baseRace.boost(0);

        // Test 3: Cannot boost if not token owner
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        baseRace.transferFrom(admin, user0, 0);
        vm.expectRevert(NotNFTOwner.selector);
        baseRace.boost(0);

        // Test 4: Cannot boost same token twice in a lap
        baseRace.boost(1);
        vm.expectRevert(HasBoosted.selector);
        baseRace.boost(1);

        // Test 5: Cannot boost non-existent token

        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 99));
        baseRace.boost(99); // InvalidPointer error from DLL

        // Test 6: Cannot boost token from previous race
        vm.warp(block.timestamp + 1.01 days);
        baseRace.finishGame();
        baseRace.startGame();
        baseRace.mint{value: mintFee}();
        baseRace.mint{value: mintFee}(); // Need at least 2 runners
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        vm.expectRevert(NotNFTOwner.selector); // InvalidPointer error from DLL
        baseRace.boost(0); // Token from previous race
    }

    function testBoostSuccessConditions() public prank(admin) {
        baseRace.startGame();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        /// Get position and hasBoosted before
        (,,, uint256[] memory positionsA) = baseRace.getLap(1, 1);
        bool hasBoosted = baseRace.isBoosted(1, 1, 1);
        assertEq(hasBoosted, false);

        /// Boost
        baseRace.boost(1);

        (,,, uint256[] memory positionsB) = baseRace.getLap(1, 1);
        hasBoosted = baseRace.isBoosted(1, 1, 1);

        if (positionsA[0] == 1) {
            assertEq(positionsA[0], positionsB[0]);
        } else {
            assertEq(positionsA[0], positionsB[1]);
        }
        assertEq(hasBoosted, true);
    }

    /// START GAME ///

    function testStartGameRevertConditions() public prank(admin) {
        baseRace.startGame();

        /// Wrong status - InMint
        vm.expectRevert(WrongStatus.selector);
        baseRace.startGame();

        // Mint minimum required runners (2) before testing InRace status
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();

        /// Wrong status - InRace
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(WrongStatus.selector);
        baseRace.startGame();
    }

    function testStartGameSuccessConditions() public prank(admin) {
        (, uint256 startedAt,,,,,) = baseRace.getRace(1);
        assertEq(startedAt, 0);
        assert(baseRace.status() == GameStatus.Pending);

        vm.expectEmit(true, true, true, true);
        emit GameStarted(1, block.timestamp);
        baseRace.startGame();

        (, startedAt,,,,,) = baseRace.getRace(1);
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

        // Mint enough runners to get 6 laps (need at least 33 runners)
        for (uint256 i = 0; i < 33; i++) {
            baseRace.mint{value: baseRace.mintFee()}();
        }

        /// Lap still active
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(LapStillActive.selector);
        baseRace.startNextLap();

        /// Progress through all laps to test final lap condition
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Lap 2
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Lap 3
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Lap 4
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Lap 5
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Lap 6 (final)
        vm.warp(block.timestamp + 1.01 days);

        vm.expectRevert(IsFinalLap.selector);
        baseRace.startNextLap();
    }

    function testStartNextLapSuccessConditions() public prank(admin) {
        baseRace.startGame();

        // Mint 4 runners to get 2 laps
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();

        // Initial state checks
        (,,, uint256 lapTotal, uint256 lapCount,,) = baseRace.getRace(1);
        assertEq(lapCount, 0);
        assertEq(lapTotal, 2);
        assert(baseRace.status() == GameStatus.InMint);

        // Start first lap
        vm.warp(block.timestamp + 1.01 days);
        vm.expectEmit(true, true, true, true);
        emit LapStarted(1, 1, block.timestamp);
        baseRace.startNextLap();

        // Check state after first lap starts
        (,,,, lapCount,,) = baseRace.getRace(1);
        assertEq(lapCount, 1);
        assert(baseRace.status() == GameStatus.InRace);

        // Start second lap
        vm.warp(block.timestamp + 1.01 days);
        vm.expectEmit(true, true, true, true);
        emit LapStarted(1, 2, block.timestamp);
        baseRace.startNextLap();

        // Check state after second lap starts
        (,,,, lapCount,,) = baseRace.getRace(1);
        assertEq(lapCount, 2);

        // Verify we can't start another lap (final lap reached)
        vm.warp(block.timestamp + 1.01 days);
        vm.expectRevert(IsFinalLap.selector);
        baseRace.startNextLap();
    }

    function testEliminateRunners() public prank(admin) {
        baseRace.startGame();

        for (uint256 i = 0; i < 7; i++) {
            baseRace.mint{value: 0.001 ether}();
        }

        /// Lap 1
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        (uint256 entries,,, uint256 lapTotal, uint256 lapCount,,) = baseRace.getRace(1);
        assertEq(entries, 7);
        assertEq(lapCount, 1);
        assertEq(lapTotal, 5);

        (,, uint256 eliminations, uint256[] memory positions) = baseRace.getLap(1, 1);
        assertEq(eliminations, 1);
        assertEq(positions.length, 7);

        /// Lap 2
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 2);
        assertEq(eliminations, 1);
        assertEq(positions.length, 6);

        /// Lap 3
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 3);
        assertEq(eliminations, 1);
        assertEq(positions.length, 5);

        /// Lap 4
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 4);
        assertEq(eliminations, 1);
        assertEq(positions.length, 4);

        /// Lap 5
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 5);
        assertEq(eliminations, 2);
        assertEq(positions.length, 3);
    }

    function testEliminate30Runners() public prank(admin) {
        baseRace.startGame();

        for (uint256 i = 0; i < 30; i++) {
            baseRace.mint{value: 0.001 ether}();
        }

        /// Lap 1
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        (uint256 entries,,, uint256 lapTotal, uint256 lapCount,,) = baseRace.getRace(1);
        assertEq(entries, 30);
        assertEq(lapCount, 1);
        assertEq(lapTotal, 6);

        (,, uint256 eliminations, uint256[] memory positions) = baseRace.getLap(1, 1);
        assertEq(eliminations, 5);
        assertEq(positions.length, 30);

        /// Lap 2
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 2);
        assertEq(eliminations, 5);
        assertEq(positions.length, 25);

        /// Lap 3
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 3);
        assertEq(eliminations, 5);
        assertEq(positions.length, 20);

        /// Lap 4
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 4);
        assertEq(eliminations, 5);
        assertEq(positions.length, 15);

        /// Lap 5
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 5);
        assertEq(eliminations, 5);
        assertEq(positions.length, 10);

        /// Lap 6
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 6);
        assertEq(eliminations, 4);
        assertEq(positions.length, 5);
    }

    function testEliminate115Runners() public prank(admin) {
        baseRace.startGame();

        for (uint256 i = 0; i < 115; i++) {
            baseRace.mint{value: 0.001 ether}();
        }

        /// Lap 1
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        (uint256 entries,,, uint256 lapTotal, uint256 lapCount,,) = baseRace.getRace(1);
        assertEq(entries, 115);
        assertEq(lapCount, 1);
        assertEq(lapTotal, 6);

        (,, uint256 eliminations, uint256[] memory positions) = baseRace.getLap(1, 1);
        assertEq(eliminations, 18);
        assertEq(positions.length, 115);

        /// Lap 2
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 2);
        assertEq(eliminations, 18);
        assertEq(positions.length, 97);

        /// Lap 3
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 3);
        assertEq(eliminations, 18);
        assertEq(positions.length, 79);

        /// Lap 4
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 4);
        assertEq(eliminations, 18);
        assertEq(positions.length, 61);

        /// Lap 5
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 5);
        assertEq(eliminations, 18);
        assertEq(positions.length, 43);

        /// Lap 6
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();
        (,, eliminations, positions) = baseRace.getLap(1, 6);
        assertEq(eliminations, 24);
        assertEq(positions.length, 25);
    }

    /// FINISH GAME ///

    function testFinishGameRevertConditions() public prank(admin) {
        /// Wrong status - Pending
        vm.expectRevert(WrongStatus.selector);
        baseRace.finishGame();

        /// Wrong status - InMint
        baseRace.startGame();

        // Mint 4 runners to have a 2-lap race (as per testSmallRaceLaps)
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();
        baseRace.mint{value: baseRace.mintFee()}();

        vm.expectRevert(WrongStatus.selector);
        baseRace.finishGame();

        /// Final lap not reached (only on lap 1)
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        vm.expectRevert(FinalLapNotReached.selector);
        baseRace.finishGame();

        /// Start final lap but try to finish too early
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Start lap 2 (final lap)

        /// Lap still active (try to finish before lap time is up)
        vm.expectRevert(LapStillActive.selector);
        baseRace.finishGame();
    }

    function testFinishGameSuccessConditions() public prank(admin) {
        baseRace.startGame();

        // Mint two runners - with 2 runners we get 1 lap according to _calcLaps
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        // Start and complete the only lap needed
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap(); // Start lap 1 (final lap)
        vm.warp(block.timestamp + 1.01 days); // Wait for lap time to complete

        uint256 mintFee = baseRace.mintFee();
        uint256 winnerBalanceBefore = admin.balance;
        uint256 expectedPrize = 2 * (mintFee - (mintFee * baseRace.burnPercentage()) / 10_000);
        assertEq(address(baseRace).balance, expectedPrize);

        // Check endedAt is 0 before finishing
        (,,,,,, uint256 endedAt) = baseRace.getRace(1);
        assertEq(endedAt, 0);

        vm.expectEmit(true, true, true, true);
        emit GameEnded(1, block.timestamp);
        baseRace.finishGame();

        // Check endedAt is set after finishing
        (,,,,,, endedAt) = baseRace.getRace(1);
        assertEq(endedAt, block.timestamp);

        assertEq(address(baseRace).balance, 0);
        assertEq(admin.balance, winnerBalanceBefore + expectedPrize);
        assert(baseRace.status() == GameStatus.Pending);
    }

    function testEndedAtTimestamps() public prank(admin) {
        baseRace.startGame();

        // Mint 4 runners to get 2 laps
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();
        baseRace.mint{value: 0.001 ether}();

        // Start first lap
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        // Check first lap endedAt is set
        (uint256 lapStartedAt, uint256 lapEndedAt,,) = baseRace.getLap(1, 1);
        assertEq(lapEndedAt, block.timestamp);

        // Start second lap
        vm.warp(block.timestamp + 1.01 days);
        baseRace.startNextLap();

        // Check second lap endedAt is set
        (lapStartedAt, lapEndedAt,,) = baseRace.getLap(1, 2);
        assertEq(lapEndedAt, block.timestamp);

        // Check race endedAt is still 0
        (,,,,,, uint256 raceEndedAt) = baseRace.getRace(1);
        assertEq(raceEndedAt, 0);

        // Finish race
        vm.warp(block.timestamp + 1.01 days);
        baseRace.finishGame();

        // Check race endedAt is now set
        (,,,,,, raceEndedAt) = baseRace.getRace(1);
        assertEq(raceEndedAt, block.timestamp);
    }

    /// SETTINGS ///

    /// ART ///
}
