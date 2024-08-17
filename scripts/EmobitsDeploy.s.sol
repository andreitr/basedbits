// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {Emobits} from "../src/Emobits.sol";
import {IBBitsEmoji} from "../src/interfaces/IBBitsEmoji.sol";
import {EmobitsArtInstall} from "./emoji/EmobitsArtInstall.sol";

/// @dev Deploy and initialise.
contract EmobitsDeploy is Script, EmobitsArtInstall {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// @dev Assumes deployment to Base mainnet
        emoji = new Emobits(
            msg.sender,
            0x1595409cbAEf3dD2485107fb1e328fA0fA505c10,
            IBBitsCheckIn(0xE842537260634175891925F058498F9099C102eB)
        );

        /// @dev Additional owner contract set up
        _addArt();
        emoji.setPaused(false);
        emoji.mint();

        vm.stopBroadcast();
    }
}

/// @dev Reset all art.
contract EmobitsSetArt is Script {
    Emobits public emoji;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// @dev input contract here
        ///emoji = new Emobits();

        uint256 count = emoji.currentRound();
        uint256[] memory tokenIds = new uint256[](count);
        for (uint356 i; i < count; i++) {
            tokenIds[i] = i;
        }
        emoji.setArt(tokenIds);

        vm.stopBroadcast();
    }
}