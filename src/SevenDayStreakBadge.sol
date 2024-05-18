// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1155Mintable} from "./interfaces/IERC1155Mintable.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";

contract SevenDayStreakBadge is Ownable {

    address public bBitsCheckInAddress;
    address public erc1155Address;
    mapping(address => bool) public hasMinted;
    uint256 public tokenId;

    event BadgeMinted(address indexed user, uint256 timestamp);

    constructor(address _bBitsCheckInAddress, address _erc1155Address, uint256 _tokenId, address _initialOwner) Ownable(_initialOwner) {
        bBitsCheckInAddress = _bBitsCheckInAddress;
        erc1155Address = _erc1155Address;
        tokenId = _tokenId;
    }

    function mint() external {
        require(!hasMinted[msg.sender], "Badge already minted by this address");

        (, uint16 streak, uint16 count) = IBBitsCheckIn(bBitsCheckInAddress).checkIns(msg.sender);
        require(streak >= 7, "Must have a 7-day streak to mint a badge");

        hasMinted[msg.sender] = true;

        IERC1155Mintable(erc1155Address).mint(msg.sender, tokenId, 1, "");

        emit BadgeMinted(msg.sender, block.timestamp);
    }

    function canMint(address user) external view returns (bool) {
        if (hasMinted[user]) {
            return false;
        }

        (, uint16 streak, uint16 count) = IBBitsCheckIn(bBitsCheckInAddress).checkIns(user);
        return streak >= 7;
    }

    function updateCheckInAddress(address newAddress) external onlyOwner {
        bBitsCheckInAddress = newAddress;
    }

    function updateBadgeCollectionAddress(address newAddress) external onlyOwner {
        erc1155Address = newAddress;
    }

    function updateBadgeTokenId(uint256 newTokenId) external onlyOwner {
        tokenId = newTokenId;
    }
}