// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155SupplyExtended} from "./emoji/ERC1155SupplyExtended.sol";
import {BBitsEmojiArt} from "./emoji/BBitsEmojiArt.sol";

/// @title  Based Bits Emoji
/// @notice This contract 
contract BBitsEmoji is ERC1155SupplyExtended, ReentrancyGuard, Ownable, Pausable, BBitsEmojiArt {
    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @notice Percentage of funds used to buy and burn the BBITS token.
    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    /// @notice Length of time that a raffle lasts.
    uint256 public mintDuration;

    /// @notice The price to mint an NFT.
    uint256 public mintPrice;

    /// @notice The token id of the current daily NFT.
    uint256 public currentDay;

    /// @notice Daily raffle information.
    mapping(uint256 => Day) public raffleInfo;

    /// @notice A mapping to track addresses that have entered any given raffle.
    /// @dev    raffleId => address => entered
    mapping(uint256 => mapping(address => bool)) public hasEnteredRaffle;

    /// @notice A mapping to track the total number of entries in each raffle.
    /// @dev    raffleId => totalEntries
    mapping(uint256 => uint256) public totalEntries;

    constructor(address _owner, address _burner) ERC1155("") Ownable(_owner) {
        burner = Burner(_burner);
        burnPercentage = 4000;
        mintDuration = 1 days;
        mintPrice = 0.0001 ether;
        _pause();
    }

    receive() external payable {}

    function mint() external payable nonReentrant whenNotPaused {
        if (block.timestamp - raffleInfo[currentDay].start < mintDuration) {
            /// @dev Need to add streak discount here
            if (msg.value < mintPrice) revert MustPayMintPrice();
            _mintEntry();
        } else {
            _startNewMint();
            _mintEntry();
        }
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        return _draw(_tokenId);
    }

    function raffleAmount() public view returns (uint256) {
        return address(this).balance - burnAmount();
    }

    function burnAmount() public view returns (uint256) {
        return (burnPercentage * address(this).balance) / 10_000;
    }

    /// INTERNALS ///

    /// @dev can mint more than once, but raffle entry is not updated.
    function _mintEntry() internal {
        _mint(msg.sender, currentDay, 1, "");
        if (!hasEnteredRaffle[currentDay][msg.sender]) {
            hasEnteredRaffle[currentDay][msg.sender] = true;
            Entry memory entry = Entry({
                user: msg.sender,
                weight: totalBalanceOf(msg.sender)
            });
            raffleInfo[currentDay].entries.push(entry);
            totalEntries[currentDay] += totalBalanceOf(msg.sender);
        }
        raffleInfo[currentDay].mints++;    
    }

    function _startNewMint() internal {
        /// Settle old raffle
        uint256 burned = burnAmount();
        uint256 reward = raffleAmount();
        address winner = _settle();
        burner.burn{value: burned}(0);
        (bool success,) = winner.call{value: reward}("");
        if (!success) revert TransferFailed();
        raffleInfo[currentDay].rewards = reward;
        raffleInfo[currentDay].burned = burned;
        raffleInfo[currentDay].winner = winner; 
        emit Raffle(currentDay, raffleInfo[currentDay].mints, winner, reward, burned);
        /// Start new raffle
        ++currentDay;
        raffleInfo[currentDay].tokenId = currentDay;
        raffleInfo[currentDay].start = block.timestamp;
    }

    function _settle() internal view returns (address) {
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(msg.sender, blockhash(block.number - 1)))) 
            % totalEntries[currentDay];
        uint256 weight;
        uint256 length = raffleInfo[currentDay].entries.length;
        for (uint256 i; i < length; ++i) {
            weight = raffleInfo[currentDay].entries[i].weight;
            if(pseudoRandom < weight) return raffleInfo[currentDay].entries[i].user;
            pseudoRandom -= weight;
        }
        return address(burner);
    }

    function _getCurrentRaffleInfo() internal view returns (Day memory) {
        return raffleInfo[currentDay];
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}