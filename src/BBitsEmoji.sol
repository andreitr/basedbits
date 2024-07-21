// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155Supply} from "./emoji/ERC1155Supply.sol";
import {BBitsEmojiArt} from "./emoji/BBitsEmojiArt.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";

/// @title  Based Bits Emoji
/// @notice This contract 
contract BBitsEmoji is ERC1155Supply, ReentrancyGuard, Ownable, Pausable, BBitsEmojiArt {
    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @notice Based Bits checkin contract.
    IBBitsCheckIn public immutable checkIn;

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

    /// @dev running total array for chunking, can then know approximately where it is (significantly reduces loops)
    ///      mapping(uint256 => uint256[]) public totalEntries;

    constructor(address _owner, address _burner, IBBitsCheckIn _checkin) ERC1155("") Ownable(_owner) {
        burner = Burner(_burner);
        checkIn = _checkin;
        burnPercentage = 4000;
        mintDuration = 1 days;
        mintPrice = 0.0005 ether;
        /// @dev Prevents panic for initial mint
        totalEntries[currentDay] = 1;
        /// @dev Begins paused to allow owner to add art
        _pause();
    }

    receive() external payable {}

    function mint() external payable nonReentrant whenNotPaused {
        if (willMintSettleRaffle()) {
            _startNewMint();
            _mintEntry();
        } else {
            if (msg.value < userMintPrice(msg.sender)) revert MustPayMintPrice();
            _mintEntry();
        }
    }

    /// OWNER ///

    function setPaused(bool _setPaused) external onlyOwner {
        _setPaused ? _pause() : _unpause();
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMintDuration(uint256 _mintDuration) external onlyOwner {
        mintDuration = _mintDuration;
    }

    function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
        if (_burnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _burnPercentage;
    }

    /// VIEW ///

    function uri(uint256 _tokenId) public view override returns (string memory) {
        return _draw(_tokenId);
    }

    function raffleAmount() public view returns (uint256) {
        return address(this).balance - burnAmount();
    }

    function burnAmount() public view returns (uint256) {
        return (burnPercentage * address(this).balance) / 10_000;
    }

    function userMintPrice(address _user) public view returns (uint256) {
        (, uint16 streak,) = checkIn.checkIns(_user);
        if (streak > 90) streak = 90;
        return mintPrice - ((mintPrice * streak) / 100);
    }

    function userEntry(uint256 _day, uint256 _index) public view returns (Entry memory) {
        if (_index >= raffleInfo[_day].entries.length) revert InvalidIndex();
        return raffleInfo[_day].entries[_index];
    }

    function willMintSettleRaffle() public view returns (bool) {
        return !(block.timestamp - raffleInfo[currentDay].start < mintDuration);
    }

    /// INTERNAL ///

    /// @dev can mint more than once, but raffle entry is not updated (keeps logic simpler)
    function _mintEntry() internal {
        _mint(msg.sender, currentDay, 1, "");
        raffleInfo[currentDay].mints++;
        if (!hasEnteredRaffle[currentDay][msg.sender]) {
            hasEnteredRaffle[currentDay][msg.sender] = true;
            Entry memory entry = Entry({
                user: msg.sender,
                weight: totalBalanceOf(msg.sender)
            });
            raffleInfo[currentDay].entries.push(entry);
            totalEntries[currentDay] += totalBalanceOf(msg.sender);
        }    
    }

    function _startNewMint() internal {
        /// Settle old raffle
        uint256 burned = burnAmount();
        uint256 reward = raffleAmount();
        address winner = _settle();
        if (burned > 0) burner.burn{value: burned}(0);
        (bool success,) = winner.call{value: reward}("");
        if (!success) revert TransferFailed();
        raffleInfo[currentDay].rewards = reward;
        raffleInfo[currentDay].burned = burned;
        raffleInfo[currentDay].winner = winner; 
        emit Raffle(currentDay, raffleInfo[currentDay].mints, winner, reward, burned);
        /// Start new raffle
        ++currentDay;
        _set(currentDay);
        raffleInfo[currentDay].tokenId = currentDay;
        raffleInfo[currentDay].start = block.timestamp;
    }

    function _settle() internal view returns (address) {
        uint256 pseudoRandom = _getPseudoRandom(block.number, block.timestamp) % totalEntries[currentDay];
        uint256 weight;
        uint256 length = raffleInfo[currentDay].entries.length;
        for (uint256 i; i < length; ++i) {
            weight = raffleInfo[currentDay].entries[i].weight;
            if(pseudoRandom < weight) return raffleInfo[currentDay].entries[i].user;
            pseudoRandom -= weight;
        }
        return address(burner);
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}