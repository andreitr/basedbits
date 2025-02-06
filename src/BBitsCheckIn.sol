// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";

contract BBitsCheckIn is IBBitsCheckIn, Ownable, Pausable {
    mapping(address => bool) public collections;
    mapping(address => bool) public banned;
    mapping(address => UserCheckIns) public checkIns;

    address[] private collectionList;

    struct UserCheckIns {
        uint256 lastCheckIn;
        uint16 streak;
        uint16 count;
    }

    event CheckIn(address indexed sender, uint256 timestamp, uint16 streak, uint16 totalCheckIns);
    event CollectionAdded(address indexed collectionAddress);
    event CollectionRemoved(address indexed collectionAddress);

    constructor(address _initialCollection, address _initialOwner) Ownable(_initialOwner) {
        collections[_initialCollection] = true;
        collectionList.push(_initialCollection);
        emit CollectionAdded(_initialCollection);
    }

    function checkIn() public whenNotPaused {
        UserCheckIns storage user = checkIns[msg.sender];
        require(isEligible(msg.sender), "Must have at least one NFT from an allowed collection to check in");
        require(!banned[msg.sender], "This address is banned from posting");
        require(
            user.lastCheckIn == 0 || block.timestamp >= user.lastCheckIn + 1 days,
            "At least 24 hours must have passed since the last check-in or this is the first check-in"
        );

        user.streak = (block.timestamp >= user.lastCheckIn + 48 hours) ? 1 : user.streak + 1;
        user.lastCheckIn = block.timestamp;
        user.count += 1;

        emit CheckIn(msg.sender, block.timestamp, user.streak, user.count);
    }

    function isBanned(address _address) public view returns (bool) {
        return banned[_address];
    }

    function isEligible(address _address) public view returns (bool) {
        for (uint256 i = 0; i < collectionList.length; i++) {
            if (IERC721(collectionList[i]).balanceOf(_address) > 0) {
                return true;
            }
        }
        return false;
    }

    function canCheckIn(address _address) public view returns (bool) {
        UserCheckIns storage user = checkIns[_address];
        return isEligible(_address) && (user.lastCheckIn == 0 || block.timestamp >= user.lastCheckIn + 1 days);
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

    function unban(address _address) public onlyOwner {
        banned[_address] = false;
    }

    function addCollection(address newCollection) public onlyOwner {
        require(!collections[newCollection], "Collection already exists");
        collections[newCollection] = true;
        collectionList.push(newCollection);
        emit CollectionAdded(newCollection);
    }

    function removeCollection(address existingCollection) public onlyOwner {
        require(collections[existingCollection], "Collection does not exist");
        collections[existingCollection] = false;

        // Remove from collectionList
        for (uint256 i = 0; i < collectionList.length; i++) {
            if (collectionList[i] == existingCollection) {
                collectionList[i] = collectionList[collectionList.length - 1];
                collectionList.pop();
                break;
            }
        }
        emit CollectionRemoved(existingCollection);
    }

    function getCollections() public view returns (address[] memory) {
        return collectionList;
    }

    function migrateOldCheckIns(address oldContract, address[] calldata users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            (uint256 lastCheckIn, uint16 streak, uint16 count) = IBBitsCheckIn(oldContract).checkIns(user);
            checkIns[user] = UserCheckIns(lastCheckIn, streak, count);
        }
    }
}