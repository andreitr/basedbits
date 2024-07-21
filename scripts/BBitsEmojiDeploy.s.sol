// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {BBitsEmoji} from "../src/BBitsEmoji.sol";

contract BBitsRaffleDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// @dev Assumes deployment to Base mainnet
        BBitsEmoji raffle = new BBitsEmoji(
            msg.sender,
            0x1595409cbAEf3dD2485107fb1e328fA0fA505c10,
            IBBitsCheckIn(0xE842537260634175891925F058498F9099C102eB)
        );

        /// @dev Add art here if too big to add to EmojiArt constructor

        vm.stopBroadcast();
    }
}