// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC1155Supply} from "@src/modules/ERC1155Supply.sol";
import {Filter8Art} from "@src/modules/Filter8Art.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";

/// @title  BBMintRaffleNFT
/// @notice This contract allows users to participate in raffles by minting NFTs to win 1 of 1s.
/// @dev    The contract operates on a loop, where the creation of a new set of NFTs initiates a raffle.
///         Any user who mints that round's NFT will be entered into the raffle, with their raffle
///         weighting being equal to the total number of NFTs they have ever minted. After a
///         round has passed, the next mint settles the former raffle and provides the user with a
///         free mint. The Owner retains admin rights over pausability and the mintPrice.
contract BBMintRaffleNFT is ERC1155Supply, ReentrancyGuard, Ownable, Pausable, Filter8Art {
    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @notice Based Bits checkin contract.
    IBBitsCheckIn public immutable checkIn;

    /// @notice Filter8
    address public immutable artist;

    /// @notice The maximum number of NFTs.
    uint256 public immutable cap;

    /// @notice Percentage of funds used to buy and burn the BBITS token.
    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    /// @notice Length of time that a raffle lasts.
    uint256 public mintDuration;

    /// @notice The price to mint an NFT.
    uint256 public mintPrice;

    /// @notice The token id of the current NFT.
    uint256 public currentMint;

    /// @notice Daily raffle information.
    mapping(uint256 => Round) public mintById;

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
    constructor(address _owner, address _artist, address _burner, uint256 _cap, IBBitsCheckIn _checkin)
        ERC1155("")
        Ownable(_owner)
    {
        artist = _artist;
        burner = Burner(_burner);
        checkIn = _checkin;
        burnPercentage = 2000;
        mintDuration = 4 hours;
        mintPrice = 0.0008 ether;
        cap = _cap;
        totalEntries[currentMint] = 1;
        _pause();
    }

    receive() external payable {
        if (currentMint >= cap) revert CapExceeded();
    }

    /// @notice This function provides the core functionality for this contract, including minting, creating
    ///         raffles, settling raffles, and generating new daily art.
    function mint() external payable nonReentrant whenNotPaused {
        if (currentMint >= cap) revert CapExceeded();
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

    /// @notice This view function returns the current amount of ETH that will be awwarded to the artist.
    function currentMintArtistReward() public view returns (uint256) {
        return address(this).balance - currentMintBurnAmount();
    }

    /// @notice This view function returns the current amount of ETH that will be used to buy and burn
    ///         the BBITS token.
    function currentMintBurnAmount() public view returns (uint256) {
        return (burnPercentage * address(this).balance) / 10_000;
    }

    /// @notice This view function returns the current price to mint an NFT for any given user. Users can
    ///         decrease their mint price by up to 90% by gaining a streak in the associated BBits CheckIn
    ///         contract: 0xE842537260634175891925F058498F9099C102eB. This discount only applies to the
    ///         first mint of every round however.
    /// @param  _user The user paying to mint a new NFT.
    function userMintPrice(address _user) public view returns (uint256) {
        if (hasEnteredRaffle[currentMint][_user] == false) {
            (, uint16 streak,) = checkIn.checkIns(_user);
            if (streak > 90) streak = 90;
            return mintPrice - ((mintPrice * streak) / 100);
        } else {
            return mintPrice;
        }
    }

    /// @notice This view function returns the entry struct that corresponds to the round and index pair.
    /// @param  _round The raffle round (token Id).
    /// @param  _index The user index in the mintById array of raffle entries.
    function userEntryByIndex(uint256 _round, uint256 _index) public view returns (Entry memory) {
        if (_index >= mintById[_round].entries.length) revert InvalidIndex();
        return mintById[_round].entries[_index];
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
        return !(block.timestamp - mintById[currentMint].startedAt < mintDuration);
    }

    /// INTERNAL ///

    /// @dev User can mint more than once per round, but their raffle entry is not updated.
    ///      This keeps the raffle logic simpler.
    function _mintEntry() internal {
        _mint(msg.sender, currentMint, 1, "");
        mintById[currentMint].mints++;
        if (!hasEnteredRaffle[currentMint][msg.sender]) {
            hasEnteredRaffle[currentMint][msg.sender] = true;
            userEntryAmount[currentMint][msg.sender] = totalBalanceOf(msg.sender);
            Entry memory entry = Entry({user: msg.sender, weight: totalBalanceOf(msg.sender)});
            mintById[currentMint].entries.push(entry);
            totalEntries[currentMint] += totalBalanceOf(msg.sender);
        }
    }

    function _startNewMint() internal {
        /// Settle old raffle
        uint256 burned = currentMintBurnAmount();
        uint256 artistReward = currentMintArtistReward();
        address winner = _settle();
        if (burned > 0) burner.burn{value: burned}(0);
        (bool success,) = artist.call{value: artistReward}("");
        if (!success) revert TransferFailed();
        mintById[currentMint].rewards = artistReward;
        mintById[currentMint].winningId = currentMint + 1;
        mintById[currentMint].burned = burned;
        mintById[currentMint].winner = winner;
        mintById[currentMint].settledAt = block.timestamp;
        emit End(currentMint, mintById[currentMint].mints, winner, artistReward, burned);
        ++currentMint;
        _set(currentMint);
        _mint(winner, currentMint, 1, "");
        mintById[currentMint].winner = winner;
        mintById[currentMint].settledAt = block.timestamp;
        /// Start new raffle
        ++currentMint;
        _set(currentMint);
        mintById[currentMint].tokenId = currentMint;
        mintById[currentMint].startedAt = block.timestamp;
        emit Start(currentMint);
    }

    function _settle() internal view returns (address) {
        uint256 pseudoRandom = _getPseudoRandom(block.number, block.timestamp) % totalEntries[currentMint];
        uint256 weight;
        uint256 length = mintById[currentMint].entries.length;
        for (uint256 i; i < length; ++i) {
            weight = mintById[currentMint].entries[i].weight;
            if (pseudoRandom < weight) return mintById[currentMint].entries[i].user;
            pseudoRandom -= weight;
        }
        return address(artist);
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}
