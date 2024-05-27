// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {BBitsBadges} from "../BBitsBadges.sol";

contract BBitsBadgeFirstClick is Ownable, ReentrancyGuard {
    BBitsBadges public badgeContract;
    mapping(address => bool) public minter;
    mapping(address => bool) public minted;
    uint256 public tokenId;

    constructor(
        address[] memory _minters,
        BBitsBadges _badgeContract,
        uint256 _tokenId,
        address _initialOwner
    ) Ownable(_initialOwner) {
        badgeContract = _badgeContract;
        tokenId = _tokenId;

        for (uint256 i = 0; i < _minters.length; i++) {
            minter[_minters[i]] = true;
        }
    }

    function mint() external nonReentrant {
        require(canMint(msg.sender), "User is not eligible to mint");
        minted[msg.sender] = true;
        badgeContract.mint(msg.sender, tokenId);
    }

    function canMint(address user) public view returns (bool) {
        return !minted[user] && minter[user];
    }

    function updateBadgeContract(BBitsBadges newAddress) external onlyOwner {
        badgeContract = newAddress;
    }

    function updateBadgeTokenId(uint256 newTokenId) external onlyOwner {
        tokenId = newTokenId;
    }

    function addMinter(address newMinter) external onlyOwner {
        minter[newMinter] = true;
    }

    function removeMinter(address existingMinter) external onlyOwner {
        minter[existingMinter] = false;
    }
}