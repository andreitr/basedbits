// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {Pausable} from "lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "lib/openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract BBSocial is Ownable, Pausable {

    uint16 public threshold; // Minimum number of NFTs a user must hold to post messages
    address public collection; // Address of the NFT collection required for posting messages

    mapping(uint256 => uint256) public nftPostCount; // Mapping to keep track of post counts for each NFT
    mapping(address => uint256) public walletPostCount; // Mapping to keep track of post counts for each wallet

    event MessagePosted(address indexed sender, string message);
    event ThresholdUpdated(uint16 newThreshold);

    constructor(uint16 _postThreshold, address _collection, address _initialOwner) Ownable(_initialOwner) {
        threshold = _postThreshold;
        collection = _collection;
    }

    function postMessage(string memory message) public whenNotPaused {
        require(IERC721(collection).balanceOf(msg.sender) >= threshold, "Not enough NFTs to post");
        uint256 totalTokens = IERC721(collection).balanceOf(msg.sender);
        for (uint256 i = 0; i < totalTokens; i++) {
            uint256 tokenId = IERC721Enumerable(collection).tokenOfOwnerByIndex(msg.sender, i);
            nftPostCount[tokenId] += 1; // Increment the post count for each NFT owned by the sender
        }
        walletPostCount[msg.sender] += 1; // Increment the post count for the sender's wallet
        emit MessagePosted(msg.sender, message);
    }

    function getWalletPostCount(address wallet) public view returns (uint256) {
        return walletPostCount[wallet];
    }

    function getNftPostCount(uint256 tokenId) public view returns (uint256) {
        return nftPostCount[tokenId];
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
}