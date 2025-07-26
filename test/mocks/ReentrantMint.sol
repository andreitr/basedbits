// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {PotRaider} from "@src/PotRaider.sol";

contract ReentrantMint {
    PotRaider public potRaider;
    bool public reentered;

    constructor(PotRaider _potRaider) {
        potRaider = _potRaider;
    }

    function attack() external payable {
        potRaider.mint{value: msg.value}(1);
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            potRaider.mint{value: potRaider.mintPrice()}(1);
        }
    }
}
