// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IBBitsCheckIn} from "../src/interfaces/IBBitsCheckIn.sol";
import {BBitsRaffle} from "../src/BBitsRaffle.sol";

contract BBitsRaffleDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        /// @dev Assumes deployment to Base mainnet
        BBitsRaffle raffle = new BBitsRaffle(
            msg.sender,
            IERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407),
            IBBitsCheckIn(0xE842537260634175891925F058498F9099C102eB)
        );

        vm.stopBroadcast();
    }
}