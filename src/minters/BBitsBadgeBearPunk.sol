// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {BBitsCheckIn} from "../BBitsCheckIn.sol";
import {BBitsBadges} from "../BBitsBadges.sol";

contract BBitsBadgeBearPunk is Ownable, ReentrancyGuard {
    IERC721 public immutable bearPunks;
    BBitsCheckIn public checkInContract;
    BBitsBadges public badgeContract;
    uint256 public tokenId;
    mapping(address => bool) public minted;

    constructor(
        IERC721 _bearPunks,
        BBitsCheckIn _checkInContractAddress,
        BBitsBadges _badgeContractAddress,
        uint256 _tokenId, 
        address _initialOwner
    ) Ownable(_initialOwner) {
        bearPunks = _bearPunks;
        checkInContract = _checkInContractAddress;
        badgeContract = _badgeContractAddress;
        tokenId = _tokenId;
    }

    function mint() external nonReentrant {
        require(canMint(msg.sender), "User is not eligible to mint");
        minted[msg.sender] = true;
        badgeContract.mint(msg.sender, tokenId);
    }

    function canMint(address user) public view returns (bool) {
        if (minted[user]) return false;
        if (bearPunks.balanceOf(user) == 0) return false;
        (, uint16 streak,) = checkInContract.checkIns(user);
        return streak >= 7;
    }

    function updateCheckInContract(BBitsCheckIn newAddress) external onlyOwner {
        checkInContract = newAddress;
    }

    function updateBadgeContract(BBitsBadges newAddress) external onlyOwner {
        badgeContract = newAddress;
    }

    function updateBadgeTokenId(uint256 newTokenId) external onlyOwner {
        tokenId = newTokenId;
    }
}