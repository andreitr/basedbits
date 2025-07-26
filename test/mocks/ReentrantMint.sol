// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {PotRaider} from "@src/PotRaider.sol";

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}

contract ReentrantMint is Burner {
    PotRaider public potRaider;
    bool public reentered;

    constructor(PotRaider _potRaider) {
        potRaider = _potRaider;
    }

    function attack() external payable {
        potRaider.mint{value: msg.value}(1);
    }

    function burn(uint256) external payable {
        if (!reentered) {
            reentered = true;
            potRaider.mint{value: potRaider.mintPrice()}(1);
        }
    }

    receive() external payable {
        if (!reentered) {
            reentered = true;
            potRaider.mint{value: potRaider.mintPrice()}(1);
        }
    }
}
