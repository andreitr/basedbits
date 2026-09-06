// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @dev Stand-in for BBitsBurner.burn{value}(minOut): records ETH received. Cast to BBitsBurner in tests.
contract MockBurner {
    uint256 public calls;
    uint256 public totalReceived;
    uint256 public lastMinAmountBurned;

    receive() external payable {}

    function burn(uint256 _minAmountBurned) external payable {
        calls++;
        totalReceived += msg.value;
        lastMinAmountBurned = _minAmountBurned;
    }
}
