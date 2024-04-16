// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract BBSocial is Ownable {

    uint16 public postThreshold; // Minimum number of NFTs a user must hold to post messages
    address public collection; // Address of the NFT collection required for posting messages

    event MessagePosted(address indexed sender, string message);
    event ThresholdUpdated(uint16 newThreshold);
    event CollectionUpdated(address newCollection);

    constructor(uint16 _postThreshold, address _collection, address _initialOwner) Ownable(_initialOwner) {
        postThreshold = _postThreshold;
        collection = _collection;
    }

    function postMessage(string memory message) public {
        require(IERC721(collection).balanceOf(msg.sender) >= postThreshold, "Sender does not have enough NFTs to post");
        emit MessagePosted(msg.sender, message);
    }

    function updateThreshold(uint16 newThreshold) public onlyOwner {
        postThreshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function updateCollection(address newCollection) public onlyOwner {
        collection = newCollection;
        emit CollectionUpdated(newCollection);
    }
}
