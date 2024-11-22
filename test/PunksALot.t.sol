// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, PunksALot, BBitsCheckIn, BBitsBurner, console} from "@test/utils/BBitsTestUtils.sol";

/// @dev forge test --match-contract PunksALotTest -vvv
contract PunksALotTest is BBitsTestUtils {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 1e18);
        vm.deal(user0, 1e18);
        vm.deal(user1, 1e18);

        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        punksALot = new PunksALot(owner, user0, address(burner), address(checkIn));
    }

    function testInit() public view {}
}
