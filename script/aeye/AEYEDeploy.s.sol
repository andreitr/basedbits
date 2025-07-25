// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {AEYE} from "@src/AEYE.sol";

contract AEYEDeploy is Script {
    AEYE public aeye;
    address public creator = 0x1d671d1B191323A38490972D58354971E5c1cd2A;
    address public burner = 0x1595409cbAEf3dD2485107fb1e328fA0fA505c10;

    function run() external {
        vm.startBroadcast();

        aeye = new AEYE(msg.sender, creator, burner);

        vm.stopBroadcast();
    }
}
