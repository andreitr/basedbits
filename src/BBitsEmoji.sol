// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155Supply} from "./emoji/ERC1155Supply.sol";
import {BBitsEmojiArt} from "./emoji/BBitsEmojiArt.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";

/// @title  Emobits
/// @notice This contract allows users to participate in raffles by minting NFTs to win ETH.
/// @dev    The contract operates on a loop, where the creation of a new set of NFTs initiates a raffle.
///         Any user who mints that round's NFT will be entered into the raffle, with their raffle 
///         weighting being equal to the total number of NFTs they have ever minted. After a
///         round has passed, the next mint settles the former raffle and provides the user with a
///         free mint. The Owner retains admin rights over pausability and the mintPrice.    
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

    /// @notice The token id of the current NFT.
    uint256 public currentRound;

    /// @notice Daily raffle information.
    mapping(uint256 => Round) public raffleInfo;

    /// @notice A mapping to track addresses that have entered any given raffle.
    /// @dev    raffleId => address => entered
    mapping(uint256 => mapping(address => bool)) public hasEnteredRaffle;
    
    /// @notice A mapping of user entries per raffle to assist with front-end displays.
    /// @dev    raffleId => address => entered
    mapping(uint256 => mapping(address => uint256)) private userEntryAmount;

    /// @notice A mapping to track the total number of entries in each raffle.
    /// @dev    raffleId => totalEntries
    mapping(uint256 => uint256) public totalEntries;

    /// @dev Begins paused to allow owner to add art.
    constructor(address _owner, address _burner, IBBitsCheckIn _checkin) ERC1155("") Ownable(_owner) {
        burner = Burner(_burner);
        checkIn = _checkin;
        burnPercentage = 2000;
        mintDuration = 8 hours;
        mintPrice = 0.0005 ether;
        totalEntries[currentRound] = 1;
        _pause();
    }

    receive() external payable {}

    /// @notice This function provides the core functionality for this contract, including minting, creating
    ///         raffles, settling raffles, and generating new daily art.
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

    /// @notice This view function returns the art for any given token Id.
    /// @param  _tokenId The token Id of the NFT.
    function uri(uint256 _tokenId) public view override returns (string memory) {
        return _draw(_tokenId);
    }

    /// @notice This view function returns the current amount of ETH that will be awwarded to the daily
    ///         raffle winner.
    function raffleAmount() public view returns (uint256) {
        return address(this).balance - burnAmount();
    }

    /// @notice This view function returns the current amount of ETH that will be used to buy and burn
    ///         the BBITS token.
    function burnAmount() public view returns (uint256) {
        return (burnPercentage * address(this).balance) / 10_000;
    }

    /// @notice This view function returns the current price to mint an NFT for any given user. Users can
    ///         decrease their mint price by up to 90% by gaining a streak in the associated BBits CheckIn
    ///         contract: 0xE842537260634175891925F058498F9099C102eB.
    /// @param  _user The user paying to mint a new NFT.
    function userMintPrice(address _user) public view returns (uint256) {
        (, uint16 streak,) = checkIn.checkIns(_user);
        if (streak > 90) streak = 90;
        return mintPrice - ((mintPrice * streak) / 100);
    }

    /// @notice This view function returns the entry struct that corresponds to the round and index pair.
    /// @param  _round The raffle round (token Id).
    /// @param  _index The user index in the raffleInfo array of raffle entries.
    function userEntryByIndex(uint256 _round, uint256 _index) public view returns (Entry memory) {
        if (_index >= raffleInfo[_round].entries.length) revert InvalidIndex();
        return raffleInfo[_round].entries[_index];
    }

    /// @notice This view function returns the entry amount that corresponds to the round and user pair.
    /// @param  _round The raffle round (token Id).
    /// @param  _user The user address that has entered the raffle.
    function userEntryByAddress(uint256 _round, address _user) public view returns (uint256) {
        return userEntryAmount[_round][_user];
    }

    /// @notice This view function returns a boolean outlining whether calling the mint function will
    ///         presently settle the raffle.
    function willMintSettleRaffle() public view returns (bool) {
        return !(block.timestamp - raffleInfo[currentRound].startedAt < mintDuration);
    }

    /// INTERNAL ///

    /// @dev User can mint more than once per round, but their raffle entry is not updated.
    ///      This keeps the raffle logic simpler.
    function _mintEntry() internal {
        _mint(msg.sender, currentRound, 1, "");
        raffleInfo[currentRound].mints++;
        if (!hasEnteredRaffle[currentRound][msg.sender]) {
            hasEnteredRaffle[currentRound][msg.sender] = true;
            userEntryAmount[currentRound][msg.sender] = totalBalanceOf(msg.sender);
            Entry memory entry = Entry({
                user: msg.sender,
                weight: totalBalanceOf(msg.sender)
            });
            raffleInfo[currentRound].entries.push(entry);
            totalEntries[currentRound] += totalBalanceOf(msg.sender);
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
        raffleInfo[currentRound].rewards = reward;
        raffleInfo[currentRound].burned = burned;
        raffleInfo[currentRound].winner = winner;
        raffleInfo[currentRound].settledAt = block.timestamp;
        emit End(currentRound, raffleInfo[currentRound].mints, winner, reward, burned);
        /// Start new raffle
        ++currentRound;
        _set(currentRound);
        raffleInfo[currentRound].tokenId = currentRound;
        raffleInfo[currentRound].startedAt = block.timestamp;
        emit Start(currentRound);
    }

    function _settle() internal view returns (address) {
        uint256 pseudoRandom = _getPseudoRandom(block.number, block.timestamp) % totalEntries[currentRound];
        uint256 weight;
        uint256 length = raffleInfo[currentRound].entries.length;
        for (uint256 i; i < length; ++i) {
            weight = raffleInfo[currentRound].entries[i].weight;
            if(pseudoRandom < weight) return raffleInfo[currentRound].entries[i].user;
            pseudoRandom -= weight;
        }
        return address(burner);
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}