// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}

contract MockBurner is Burner {
    receive() external payable {}
    function burn(uint256) external payable {}
}
