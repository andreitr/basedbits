// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract BBitsSocial is Ownable, Pausable {

    uint16 public threshold; // Minimum number of NFTs a user must hold to post messages
    address public collection; // Address of the NFT collection required for posting messages

    mapping(address => uint256) public walletPoints;
    mapping(address => uint256) public walletPosts;
    mapping(address => bool) public bannedWallets;

    event MessagePosted(address indexed sender, string message, uint256 timestamp);
    event ThresholdUpdated(uint16 newThreshold);

    constructor(uint16 _postThreshold, address _collection, address _initialOwner) Ownable(_initialOwner) {
        threshold = _postThreshold;
        collection = _collection;
    }

    function postMessage(string memory message) public whenNotPaused {
        uint256 senderBalance = IERC721(collection).balanceOf(msg.sender);
        require(senderBalance >= threshold, "Not enough NFTs to post message");
        require(!bannedWallets[msg.sender], "This address is banned from posting");

        walletPosts[msg.sender]++;
        walletPoints[msg.sender] += senderBalance;
        emit MessagePosted(msg.sender, message, block.timestamp);
    }

    function getWalletPosts(address wallet) public view returns (uint256) {
        return walletPosts[wallet];
    }

    function getWalletPoints(address wallet) public view returns (uint256) {
        return walletPoints[wallet];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateThreshold(uint16 newThreshold) public onlyOwner {
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function updateCollection(address newCollection) public onlyOwner {
        collection = newCollection;
    }

    function banAddress(address _address) public onlyOwner {
        bannedWallets[_address] = true;
    }

    function unbanAddress(address _address) public onlyOwner {
        bannedWallets[_address] = false;
    }

    function isBanned(address _address) public view returns (bool) {
        return bannedWallets[_address];
    }
}
