// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BBSocial is OwnableUpgradeable {

    uint16 public postThreshold;
    IERC721Upgradeable public collection;

    event MessagePosted(address indexed sender, string message);

    function initialize(IERC721Upgradeable _collection, uint16 _postThreshold) public initializer {
        __Ownable_init();
        collection = _collection;
        postThreshold = _postThreshold;
    }

    function postMessage(string memory message) public {
        require(collection.balanceOf(msg.sender) > postThreshold, "Sender does not have enough NFTs to post");
        emit MessagePosted(msg.sender, message);
    }

    function updateThreshold(uint16 newThreshold) public onlyOwner {
        postThreshold = newThreshold;g
    }

    function updateCollection(IERC721Upgradeable newCollection) public onlyOwner {
        collection = newCollection;
    }
}