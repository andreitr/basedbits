// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {AEYE} from "@src/AEYE.sol";

contract AEYESepoliaDeploy is Script {
    AEYE public aeye;

    function run() external {
        vm.startBroadcast();

        MockBurner mockBurner = new MockBurner();
        aeye = new AEYE(
            0x1d671d1B191323A38490972D58354971E5c1cd2A,
            0x1d671d1B191323A38490972D58354971E5c1cd2A,
            address(mockBurner)
        );
        vm.stopBroadcast();
    }
}

contract MockBurner {
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
