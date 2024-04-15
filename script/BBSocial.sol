// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

contract BBSocial is OwnableUpgradeable {

    uint16 public postThreshold;
    address public collection;

    event MessagePosted(address indexed sender, string message);

    function initialize(address _collection, uint16 _postThreshold) public initializer {
        __Ownable_init()
        collection = _collection;
        postThreshold = _postThreshold;
    }


    function postMessage(string memory message) public {
        IERC721Upgradeable nftCollection = IERC721Upgradeable(collection);
        require(nftCollection.balanceOf(msg.sender) > postThreshold, "Sender does not have enough NFTs to post");
        emit MessagePosted(msg.sender, message);
    }
    function updateThreshold(uint16 newThreshold) public onlyOwner {
        postThreshold = newThreshold;
    }

    function updateCollection(address newCollection) public onlyOwner {
        collection = newCollection;
    }
}