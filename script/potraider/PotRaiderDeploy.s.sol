// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PotRaider} from "@src/PotRaider.sol";

contract PotRaiderDeploy is Script {
        
    PotRaider public potRaider;
    address public burner = 0x1595409cbAEf3dD2485107fb1e328fA0fA505c10;
    address public artist = 0x1d671d1B191323A38490972D58354971E5c1cd2A;

    function run() external {
        vm.startBroadcast();

        potRaider = new PotRaider(
            0.0008 ether,           // mintPrice
            burner,                 // burnerContract
            artist                  // artist
        );

        vm.stopBroadcast();
    }
} 