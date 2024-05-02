// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract BBitsCheckIn is Ownable, Pausable {

    address public collection;
    mapping(address => bool) public bannedWallets;
    mapping(address => UserData) public userData;

    struct UserData {
        uint256 lastCheckIn;
        uint256 streak;
        uint256 checkInCount;
    }

    event CheckedIn(address indexed sender, uint256 timestamp, uint256 checkInCount, uint256 streak);

    constructor(address _collection, address _initialOwner) Ownable(_initialOwner) {
        collection = _collection;
    }

    function checkIn() public whenNotPaused {
        UserData storage user = userData[msg.sender];
        require(IERC721(collection).balanceOf(msg.sender) > 0, "Must have at least one NFT to check in");
        require(!bannedWallets[msg.sender], "This address is banned from posting");
        require(user.lastCheckIn == 0 || block.timestamp >= user.lastCheckIn + 1 days, "At least 24 hours must have passed since the last check-in or this is the first check-in");

        user.streak = (block.timestamp >= user.lastCheckIn + 48 hours) ? 1 : user.streak + 1;
        user.lastCheckIn = block.timestamp;
        user.checkInCount++;

        emit CheckedIn(msg.sender, block.timestamp, user.checkInCount, user.streak);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function ban(address _address) public onlyOwner {
        bannedWallets[_address] = true;
    }

    function isBanned(address _address) public view returns (bool) {
        return bannedWallets[_address];
    }

    function unban(address _address) public onlyOwner {
        bannedWallets[_address] = false;
    }

    function updateCollection(address newCollection) public onlyOwner {
        collection = newCollection;
    }

    function userStats(address _address) public view returns (uint256, uint256, uint256) {
        UserData storage user = userData[_address];
        return (user.lastCheckIn, user.streak, user.checkInCount);
    }
}