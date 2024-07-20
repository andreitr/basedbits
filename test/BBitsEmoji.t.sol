// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsEmoji, console} from "./utils/BBitsTestUtils.sol";
import {IBBitsEmoji} from "../src/interfaces/IBBitsEmoji.sol";

contract BBitsEmojiTest is BBitsTestUtils, IBBitsEmoji {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);

        //basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        //checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        emoji = new BBitsEmoji(owner, 0x1595409cbAEf3dD2485107fb1e328fA0fA505c10);
    }

    function testInit() public {
        
    }
}