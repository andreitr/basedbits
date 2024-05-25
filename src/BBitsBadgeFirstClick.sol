// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";
import {IBBitsBadges} from "./interfaces/IBBitsBadges.sol";

contract BBitsBadgeFirstClick is Ownable {

    address public badgeContract;
    mapping(address => bool) public minter;
    mapping(address => bool) public minted;
    uint256 public tokenId;

    address[] public minters;

    constructor(address[] memory _minters, address _badgeContractAddress, uint256 _tokenId, address _initialOwner) Ownable(_initialOwner) {
        badgeContract = _badgeContractAddress;
        tokenId = _tokenId;

        for (uint256 i = 0; i < _minters.length; i++) {
            minter[_minters[i]] = true;
        }
    }

    function mint() external {
        require(!minted[msg.sender], "Badge already minted by this address");
        require(minter[msg.sender], "Not allowed to mint");

        IBBitsBadges(badgeContract).mint(msg.sender, tokenId);
        minted[msg.sender] = true;
    }

    function canMint(address user) external view returns (bool) {
        return !minted[user] && minter[user];
    }

    function updateBadgeContract(address newAddress) external onlyOwner {
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