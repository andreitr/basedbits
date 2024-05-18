// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBBitsCheckIn {
    function checkIns(address user) external view returns (uint256 lastCheckIn, uint16 streak, uint16 count);
}
