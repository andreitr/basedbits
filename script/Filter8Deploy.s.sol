// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";
import {BBMintRaffleNFT, Burner} from "@src/BBMintRaffleNFT.sol";
import {IBBMintRaffleNFT} from "@src/interfaces/IBBMintRaffleNFT.sol";
import {Filter8ArtInstall} from "@script/filter8/Filter8ArtInstall.sol";

contract Filter8Deploy is Script, Filter8ArtInstall {
    //    filter8.eth
    address public artist = 0x019B0EE245fb09aaf92aC93Ca3309832B7974681;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        filter8 = new BBMintRaffleNFT(
            msg.sender,
            artist,
            0x1595409cbAEf3dD2485107fb1e328fA0fA505c10,
            512,
            IBBitsCheckIn(0xE842537260634175891925F058498F9099C102eB)
        );

        _addArt();
        filter8.setPaused(false);
        filter8.mint();

        vm.stopBroadcast();
    }
}
