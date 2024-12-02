// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";
import {PunksALot, Burner} from "@src/PunksALot.sol";
import {IPunksALot} from "@src/interfaces/IPunksALot.sol";
import {PunksALotArtInstall} from "@script/punksALot/PunksALotArtInstall.sol";

contract PunksALotSepoliaDeploy is Script, PunksALotArtInstall {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockBurner mockBurner = new MockBurner();
        MockCheckIn mockCheckIn = new MockCheckIn();
        punksALot = new PunksALot(
            0x42e84F0bCe28696cF1D254F93DfDeaeEB6F0D67d,
            0xa2ef4A5fB028b4543700AC83e87a0B8b4572202e,
            address(mockBurner),
            address(mockCheckIn)
        );

        _addArt();
        punksALot.mint{value: 0.001 ether}();
        punksALot.mint{value: 0.001 ether}();
        punksALot.mint{value: 0.001 ether}();
        punksALot.mint{value: 0.001 ether}();

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
        return (block.timestamp - 1, streak, uint16(0));
    }

    function banned(address user) external view returns (bool) {
        user;
        streak;
        return false;
    }
}
