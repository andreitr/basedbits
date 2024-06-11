// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBBitsBadges {
    function mint(address to, uint256 id) external;
    function setURI(string memory uri) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}
