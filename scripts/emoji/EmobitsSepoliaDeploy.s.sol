// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "../../src/interfaces/IBBitsCheckIn.sol";
import {Emobits, Burner} from "../../src/Emobits.sol";
import {IBBitsEmoji} from "../../src/interfaces/IBBitsEmoji.sol";
import {EmobitsArtInstall} from "./EmobitsArtInstall.sol";

contract EmobitsSepoliaDeploy is Script, EmobitsArtInstall {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockBurner mockBurner = new MockBurner();
        MockCheckIn mockCheckIn = new MockCheckIn();
        emoji = new Emobits(0x42e84F0bCe28696cF1D254F93DfDeaeEB6F0D67d, address(mockBurner), mockCheckIn);

        _addArt();
        emoji.setPaused(false);
        emoji.mint();

        vm.stopBroadcast();
    }
}

contract Mint is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Emobits emoji = Emobits(payable(0x5C9B48e083091d47E43e2f960f890f7D0A5a0c64));

        emoji.mint{value: 0.0005 ether}();

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

contract MockCheckIn is IBBitsCheckIn {
    uint16 public streak;

    function setStreak(uint16 _streak) public {
        streak = _streak;
    }

    function checkIns(address user) external view returns (uint256, uint16, uint16) {
        user;
        return (uint256(0), streak, uint16(0));
    }

    function banned(address user) external view returns (bool) {
        user;
        streak;
        return false;
    }
}