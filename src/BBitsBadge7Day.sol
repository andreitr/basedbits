// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1155Mintable} from "./interfaces/IERC1155Mintable.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";

contract BBitsBadge7Day is Ownable {

    address public checkInContract;
    address public badgeContract;
    uint256 public tokenId;
    mapping(address => bool) public minted;

    event BadgeMinted(address indexed user, uint256 timestamp);

    constructor(address _checkInContractAddress, address _badgeContractAddress, uint256 _tokenId, address _initialOwner) Ownable(_initialOwner) {
        checkInContract = _checkInContractAddress;
        badgeContract = _badgeContractAddress;
        tokenId = _tokenId;
    }

    function mint() external {
        require(!minted[msg.sender], "Badge already minted by this address");

        (, uint16 streak,) = IBBitsCheckIn(checkInContract).checkIns(msg.sender);
        require(streak >= 7, "Must have a 7-day streak to mint a badge");

        minted[msg.sender] = true;

        IERC1155Mintable(badgeContract).mint(msg.sender, tokenId, 1, "");

        emit BadgeMinted(msg.sender, block.timestamp);
    }

    function canMint(address user) external view returns (bool) {
        if (minted[user]) {
            return false;
        }
        (, uint16 streak,) = IBBitsCheckIn(checkInContract).checkIns(user);
        return streak >= 7;
    }

    function updateCheckInContract(address newAddress) external onlyOwner {
        checkInContract = newAddress;
    }

    function updateBadgeContract(address newAddress) external onlyOwner {
        badgeContract = newAddress;
    }

    function updateBadgeTokenId(uint256 newTokenId) external onlyOwner {
        tokenId = newTokenId;
    }
}