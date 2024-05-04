// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract BBitsCheckIn is Ownable, Pausable {

    address public collection;
    mapping(address => bool) public banned;

    mapping(address => CheckInStats) public userData;

    struct CheckInStats {
        uint256 lastCheckIn;
        uint16 streak;
        uint16 count;
    }

    event CheckIn(address indexed sender, uint256 timestamp);

    constructor(address _collection, address _initialOwner) Ownable(_initialOwner) {
        collection = _collection;
    }

    function checkIn() public whenNotPaused {
        CheckInStats storage user = userData[msg.sender];
        require(IERC721(collection).balanceOf(msg.sender) > 0, "Must have at least one NFT to check in");
        require(!banned[msg.sender], "This address is banned from posting");
        require(user.lastCheckIn == 0 || block.timestamp >= user.lastCheckIn + 1 days, "At least 24 hours must have passed since the last check-in or this is the first check-in");

        user.streak = (block.timestamp >= user.lastCheckIn + 48 hours) ? 1 : user.streak + 1;
        user.lastCheckIn = block.timestamp;
        user.count += 1;

        emit CheckIn(msg.sender, block.timestamp);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function ban(address _address) public onlyOwner {
        banned[_address] = true;
    }

    function isBanned(address _address) public view returns (bool) {
        return banned[_address];
    }

    function unban(address _address) public onlyOwner {
        banned[_address] = false;
    }

    function updateCollection(address newCollection) public onlyOwner {
        collection = newCollection;
    }

    function checkInStats(address _address) public view returns (uint256, uint16, uint16) {
        CheckInStats storage stats = userData[_address];
        return (stats.lastCheckIn, stats.streak, stats.count);
    }
}