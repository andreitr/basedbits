// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, RunningGame} from "@test/utils/BBitsTestUtils.sol";
import {IRunningGame} from "@src/interfaces/IRunningGame.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract RunningGameTest -vvv
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
        /// Wrong status
        vm.expectRevert(WrongStatus.selector);
        runningGame.mint{value: 0.001 ether}();

        /// Insufficient ETH paid
        runningGame.startGame();

        vm.expectRevert(InsufficientETHPaid.selector);
        runningGame.mint();
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

        (entries,,,, prize,) = runningGame.getRace(1);
        assertEq(runningGame.totalSupply(), 1);
        assertEq(runningGame.ownerOf(0), owner);
        assertEq(address(runningGame).balance, (mintFee - (mintFee * runningGame.burnPercentage()) / 10_000));
        assertEq(entries, 1);
        assertEq(prize, address(runningGame).balance);

        /// Mint another
        runningGame.mint{value: mintFee}();

        (entries,,,, prize,) = runningGame.getRace(1);
        assertEq(runningGame.totalSupply(), 2);
        assertEq(runningGame.ownerOf(1), owner);
        assertEq(address(runningGame).balance, 2 * (mintFee - (mintFee * runningGame.burnPercentage()) / 10_000));
        assertEq(entries, 2);
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
        uint256[] memory positions = runningGame.getPositionsAtLapEnd(1, 0);
        bool hasBoosted = runningGame.getHasBoosted(1, 1, 1);
        assertEq(positions[0], 0);
        assertEq(positions[1], 1);
        assertEq(hasBoosted, false);

        /// Boost
        runningGame.boost(1);
        
        /// Note that the positions arrays are only updated at the end of each lap
        vm.warp(block.timestamp + 1.01 days);
        runningGame.startNextLap();

        positions = runningGame.getPositionsAtLapEnd(1, 1);
        hasBoosted = runningGame.getHasBoosted(1, 1, 1);
        assertEq(positions[0], 1);
        assertEq(positions[1], 0);
        assertEq(hasBoosted, true);
    }

    /// START GAME ///

    /// START NEXT LAP ///

    /// FINISH GAME ///

    /// SETTINGS ///

    /*
    function testBasic() public prank(owner) {

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

    /// ART ///
}
