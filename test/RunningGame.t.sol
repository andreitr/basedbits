// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, RunningGame} from "@test/utils/BBitsTestUtils.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract RunningGameTest -vvv
contract RunningGameTest is BBitsTestUtils {
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

    function testInit() public view {}


    function testDoesThisEvenWork() public prank(owner) {
        runningGame.startGame();

        assertEq(runningGame.getPositionsLength(), 0);
        runningGame.mint{value: 0.01 ether}();
        assertEq(runningGame.getPositionsLength(), 1);
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        runningGame.mint{value: 0.01 ether}();
        vm.warp(block.timestamp + 1 days);

        runningGame.startNextLap();

        runningGame.boost(3);
        //runningGame.boost(4);
        vm.warp(block.timestamp + 1 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1 days);
        runningGame.startNextLap();

        vm.warp(block.timestamp + 1 days);
        runningGame.finishGame();



    }

    /// ART ///
}
