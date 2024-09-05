// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, Emobits, IBBitsCheckIn, Burner, console} from "@test/utils/BBitsTestUtils.sol";
import {IBBitsEmoji} from "@src/interfaces/IBBitsEmoji.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @dev forge test --match-contract EmobitsFuzzTest --gas-report
contract EmobitsFuzzTest is BBitsTestUtils, IBBitsEmoji {
    Burner public mockBurner;
    IBBitsCheckIn public mockCheckIn;

    function setUp() public override {
        super.setUp();
        vm.warp(block.timestamp + 1.01 days);

        mockBurner = new MockBurner();
        mockCheckIn = new MockCheckIn();
        emoji = new Emobits(owner, address(mockBurner), mockCheckIn);

        /// @dev Owner contract set up
        addArt();
        vm.startPrank(owner);
        emoji.setPaused(false);
        emoji.mint();
        vm.stopPrank();
    }

    /// @dev Given first raffle weight is always 1 for each
    function testFirstRaffleFuzz(uint256 _loops) public {
        _loops = bound(_loops, 10, 5000);
        uint256 mintPrice = emoji.mintPrice();

        for (uint256 i; i < _loops; i++) {
            address user = makeAddr(Strings.toString(uint256(keccak256(abi.encodePacked(i, block.number)))));
            vm.deal(user, 1e18);
            vm.startPrank(user);
            emoji.mint{value: mintPrice}();
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 1.01 days);

        uint256 pseudoRandom =
            uint256(keccak256(abi.encodePacked(block.number, block.timestamp))) % emoji.totalEntries(1);
        uint256 weight;
        address expectedWinner;
        for (uint256 i; i < _loops + 1; ++i) {
            weight = emoji.userEntryByIndex(1, i).weight;
            if (pseudoRandom < weight) {
                expectedWinner = emoji.userEntryByIndex(1, i).user;
                break;
            } else {
                pseudoRandom -= weight;
            }
        }

        vm.expectEmit(true, true, true, true);
        emit End(
            1, _loops + 1, expectedWinner, (5000 * mintPrice * _loops) / 10_000, (5000 * mintPrice * _loops) / 10_000
        );
        emoji.mint();

        assert(expectedWinner != address(emoji.burner()));
    }

    function testNonFirstRaffleFuzz(uint256 _raffles, uint256 _loops) public {
        _raffles = bound(_raffles, 1, 10);
        _loops = bound(_loops, 10, 500);
        uint256 mintPrice = emoji.mintPrice();

        /// Can't pass _loops as length here
        address[5000] memory users;

        /// Initial raffles
        for (uint256 i; i < _raffles; i++) {
            for (uint256 j; j < _loops; j++) {
                if (i == 0) {
                    address user = makeAddr(Strings.toString(uint256(keccak256(abi.encodePacked(j, block.number)))));
                    users[j] = user;
                    vm.deal(user, 1e18);
                }
                vm.startPrank(users[j]);
                emoji.mint{value: mintPrice}();
                vm.stopPrank();
            }

            vm.warp(block.timestamp + 1.01 days);
            emoji.mint();
        }

        for (uint256 j; j < _loops; j++) {
            vm.startPrank(users[j]);
            emoji.mint{value: mintPrice}();
            vm.stopPrank();
        }
        vm.warp(block.timestamp + 1.01 days);

        uint256 pseudoRandom =
            uint256(keccak256(abi.encodePacked(block.number, block.timestamp))) % emoji.totalEntries(_raffles + 1);
        uint256 weight;
        address expectedWinner;
        for (uint256 i; i < _loops + 1; ++i) {
            weight = emoji.userEntryByIndex(_raffles + 1, i).weight;
            if (pseudoRandom < weight) {
                expectedWinner = emoji.userEntryByIndex(_raffles + 1, i).user;
                break;
            } else {
                pseudoRandom -= weight;
            }
        }

        vm.expectEmit(true, true, true, true);
        emit End(
            _raffles + 1,
            _loops + 1,
            expectedWinner,
            (5000 * mintPrice * _loops) / 10_000,
            (5000 * mintPrice * _loops) / 10_000
        );
        emoji.mint();

        assert(expectedWinner != address(emoji.burner()));
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
