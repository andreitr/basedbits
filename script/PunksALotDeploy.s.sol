// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";
import {Punkalot, Burner} from "@src/Punkalot.sol";
import {IPunksALot} from "@src/interfaces/IPunksALot.sol";
import {PunksALotArtInstall} from "@script/punksALot/PunksALotArtInstall.sol";

contract PunksALotDeploy is Script, PunksALotArtInstall {
    /// @dev !!! ADD ARTIST WALLET !!!
    address public artist = 0x5f81f6FB766d40Ceb7111FB1Eaa5c2632A617804;

    function run() external {

        vm.startBroadcast();

        punksALot = new Punkalot(
            msg.sender, artist, 0x1595409cbAEf3dD2485107fb1e328fA0fA505c10, 0xE842537260634175891925F058498F9099C102eB
        );
        _addArt();

        vm.stopBroadcast();
    }
}
