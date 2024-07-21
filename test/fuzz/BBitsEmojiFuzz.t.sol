// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils, 
    BBitsEmoji, 
    IBBitsCheckIn,
    Burner,
    console
} from "../utils/BBitsTestUtils.sol";
import {IBBitsEmoji} from "../../src/interfaces/IBBitsEmoji.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @dev forge test --match-contract BBitsEmojiFuzzTest --gas-report

contract BBitsEmojiFuzzTest is BBitsTestUtils, IBBitsEmoji {
    Burner public mockBurner;
    IBBitsCheckIn public mockCheckIn;

    function setUp() public override {
        super.setUp();
        vm.warp(block.timestamp + 1.01 days);

        mockBurner = new MockBurner();
        mockCheckIn = new MockCheckIn();
        emoji = new BBitsEmoji(owner, address(mockBurner), mockCheckIn);

        /// @dev owner set up
        addArt();
        vm.startPrank(owner);
        emoji.setPaused(false);
        emoji.mint();
        vm.stopPrank();
    }

    function testGasFuzz(uint256 _loops) public {
        _loops = bound(_loops, 10, 5000);
        uint256 mintPrice = emoji.mintPrice();

        for(uint256 i; i < _loops; i++) {
            address user = makeAddr(Strings.toString(uint256(keccak256(abi.encodePacked(i, block.number)))));
            vm.deal(user, 1e18);
            vm.startPrank(user);
            emoji.mint{value: mintPrice}();
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1.01 days);
        emoji.mint();
    }
}

/// MOCKS ///

contract MockBurner is Burner {
    receive() external payable {}

    function burn(uint256 _minAmountBurned) external payable {
        _minAmountBurned;
    }
}

contract MockCheckIn is IBBitsCheckIn {
    uint16 public streak;

    function setStreak(uint16 _streak) public {
        streak = _streak;
    }

    function checkIns(address user) external view returns (uint256, uint16, uint16) {
        user;
        return (uint256(0), streak, uint16(0));
    }

    function banned(address user) external view returns (bool) {
        user;
        streak;
        return false;
    }
}