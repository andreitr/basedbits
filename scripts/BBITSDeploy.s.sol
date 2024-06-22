// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {BBITS} from "../src/BBITS.sol";

contract BBITSDeploy is Script {
    function run() external {
        vm.startBroadcast();

        /// @dev Assumes deployment to Base mainnet
        BBITS bbits = new BBITS(
            IERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407),
            1024
        );

        vm.stopBroadcast();
    }
}