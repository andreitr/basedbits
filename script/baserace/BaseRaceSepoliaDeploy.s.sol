// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {BaseRace, Burner} from "@src/BaseRace.sol";

contract BaseRaceSepoliaDeploy is Script {
    function run() external {
    
        vm.startBroadcast();

        MockBurner mockBurner = new MockBurner();
        BaseRace baseRace = new BaseRace(
            0x1d671d1B191323A38490972D58354971E5c1cd2A, 0x04De0234a17DA9293330a9FBb3bA81C6c96DCee1, address(mockBurner)
        );
        baseRace;

        vm.stopBroadcast();
    }
}

contract MockBurner is Burner {
    address public immutable owner;

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        (bool s,) = owner.call{value: address(this).balance}("");
        require(s);
    }

    function burn(uint256 _minAmountBurned) external payable {
        _minAmountBurned;
    }
}
