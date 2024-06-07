// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";
import {IBBitsRaffle} from "./interfaces/IBBitsRaffle.sol";

/// @title  Based Bits Raffle
/// @notice This contract ...
contract BBitsRaffle is IBBitsRaffle, Ownable, ReentrancyGuard, Pausable {
    /// @notice Based Bits NFT.
    IERC721 public immutable collection;

    /// @notice Based Bits checkin contract.
    IBBitsCheckIn public immutable checkIn;

    /// @notice The current raffle status of this contract.
    ///         PendingRaffle:     Raffle not started (just deployed/just settled).
    ///         InRaffle:          Accepting entries.
    ///         PendingSettlement: No longer accepting entries but not settled.
    RaffleStatus public status;

    /// @notice The total number of raffles held by this contract.
    uint256 public count;

    /// @notice Length of time that a raffle lasts.
    uint256 public duration;

    /// @notice An fee that must be paid on some functions to discourage botting or abuse.
    uint256 public antiBotFee;

    /// @dev The value used to derive randomness when settling the raffle.
    uint256 private futureBlockNumber;

    /// @notice A mapping from raffle ids to raffle info.
    mapping(uint256 => Raffle) public idToRaffle;

    /// @notice A mapping to track addresses that have entered any given raffle.
    /// @dev raffleId => address => entered
    mapping(uint256 => mapping(address => bool)) public hasEnteredRaffle;

    /// @notice A mapping to track free token Id entries for any given raffle.
    /// @dev raffleId => tokenId => entered
    mapping(uint256 => mapping(uint256 => bool)) public tokenIdUsedForFreeEntry;

    /// @notice An array of token ids and corresponding sponsors that are held by the contract.
    SponsoredPrize[] public prizes;

    constructor(address _owner, IERC721 _collection, IBBitsCheckIn _checkIn) Ownable(_owner) {
        status = RaffleStatus.PendingRaffle;
        collection = _collection;
        checkIn = _checkIn;
        duration = 1 days;
        antiBotFee = 0.0001 ether;
        count = 1;
    }

    receive() external payable {}

    /// DEPOSIT ///

    /// @dev Can deposit under any contract status.
    function depositBasedBits(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        uint256 length = _tokenIds.length;
        if (length == 0) revert DepositZero();
        uint256 tokenId;
        SponsoredPrize memory newSponsoredPrize;
        for (uint256 i; i < length; ++i) {
            tokenId = _tokenIds[i];
            collection.transferFrom(msg.sender, address(this), tokenId);
            if (collection.ownerOf(tokenId) != address(this)) revert TransferFailed();
            newSponsoredPrize = SponsoredPrize({
                tokenId: tokenId,
                sponsor: msg.sender
            });
            prizes.push(newSponsoredPrize);
            emit BasedBitsDeposited(msg.sender, tokenId);
        }
    }

    /// START RAFFLE ///

    function startNextRaffle() external nonReentrant whenNotPaused {
        if (status != RaffleStatus.PendingRaffle) revert WrongStatus();
        uint256 prizesLength = prizes.length;
        if (prizesLength == 0) revert NoBasedBitsToRaffle();
        address[] memory newEntries;
        Raffle memory newRaffle = Raffle({
            startedAt: block.timestamp,
            settledAt: 0,
            entries: newEntries,
            winner: address(0),
            sponsoredPrize: prizes[0]
        });
        idToRaffle[count++] = newRaffle;
        status = RaffleStatus.InRaffle;
        emit NewRaffleStarted(getCurrentRaffleId());
    }

    /// ENTRIES ///

    /// @dev Passes a tokenId also to prevent re-use abuse
    function newFreeEntry(uint256 _tokenId) external nonReentrant whenNotPaused {
        if (!isEligibleForFreeEntry(msg.sender, _tokenId)) revert NotEligibleForFreeEntry();
        tokenIdUsedForFreeEntry[getCurrentRaffleId()][_tokenId] = true;
        _newEntry();
    }

    function newPaidEntry() external payable nonReentrant whenNotPaused {
        if (msg.value != antiBotFee) revert MustPayAntiBotFee();
        _newEntry();
    }

    function _newEntry() internal {
        if (status != RaffleStatus.InRaffle) revert WrongStatus();
        uint256 currentRaffleId = getCurrentRaffleId();
        Raffle storage currentRaffle = idToRaffle[currentRaffleId];
        if (block.timestamp - currentRaffle.startedAt > duration) revert RaffleExpired();
        if (hasEnteredRaffle[currentRaffleId][msg.sender]) revert AlreadyEnteredRaffle();
        hasEnteredRaffle[currentRaffleId][msg.sender] = true;
        currentRaffle.entries.push(msg.sender);
        emit RaffleEntered(currentRaffleId, msg.sender);
    }

    /// SETTLEMENT ///

    /// @dev Status can be either InRaffle or PendingSettlement to allow for re-rolling seed
    function setRandomSeed() external payable nonReentrant whenNotPaused {
        if (status == RaffleStatus.PendingRaffle) revert WrongStatus();
        uint256 currentRaffleId = getCurrentRaffleId();
        Raffle storage currentRaffle = idToRaffle[currentRaffleId];
        if (block.timestamp - currentRaffle.startedAt < duration) revert RaffleOnGoing();
        if (msg.value != antiBotFee) revert MustPayAntiBotFee();
        futureBlockNumber = block.number + 1;
        status = RaffleStatus.PendingSettlement;
        emit RandomSeedSet(currentRaffleId, futureBlockNumber);
    }

    /// @dev Only pops the prize array if there are entries
    function settleRaffle() external nonReentrant whenNotPaused {
        if (status != RaffleStatus.PendingSettlement) revert WrongStatus();
        bytes32 blockHash = blockhash(futureBlockNumber);
        if (blockHash == bytes32(0)) revert SeedMustBeReset();
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(futureBlockNumber, blockHash)));
        uint256 currentRaffleId = getCurrentRaffleId();
        Raffle storage currentRaffle = idToRaffle[currentRaffleId];
        uint256 entriesLength = currentRaffle.entries.length;
        if (entriesLength == 0) {
            currentRaffle.settledAt = block.timestamp;
            emit RaffleSettled(currentRaffleId, address(0), 0);
        } else {
            prizes[0] = prizes[prizes.length - 1];
            prizes.pop();
            address winner = currentRaffle.entries[pseudoRandom % entriesLength];
            address sponsor = currentRaffle.sponsoredPrize.sponsor;
            uint256 tokenId = currentRaffle.sponsoredPrize.tokenId;
            currentRaffle.settledAt = block.timestamp;
            currentRaffle.winner = winner;
            collection.transferFrom(address(this), winner, tokenId);
            if (collection.ownerOf(tokenId) != winner) revert TransferFailed();
            (bool success, ) = (sponsor).call{value: address(this).balance}("");
            if (!success) revert TransferFailed();
            emit RaffleSettled(currentRaffleId, winner, tokenId);
        }
        status = RaffleStatus.PendingRaffle;
    }

    /// VIEW ///
    
    /// @dev Will return zero when initially deployed but there is no raffle zero.
    function getCurrentRaffleId() public view returns (uint256) {
        return count - 1; 
    }

    function getRaffleEntryNumber(uint256 _raffleId) public view returns (uint256) {
        return idToRaffle[_raffleId].entries.length;
    }

    function getRaffleEntryByIndex(uint256 _raffleId, uint256 _index) public view returns (address) {
        if (_index >= getRaffleEntryNumber(_raffleId)) revert IndexOutOfBounds();
        return idToRaffle[_raffleId].entries[_index];
    }

    function isEligibleForFreeEntry(address _user, uint256 _tokenId) public view returns (bool) {
        if (collection.ownerOf(_tokenId) != _user) return false;
        (uint256 _lastCheckIn,,) = checkIn.checkIns(_user);
        if (block.timestamp - _lastCheckIn > 2 days) return false;
        if (tokenIdUsedForFreeEntry[getCurrentRaffleId()][_tokenId]) return false;
        return true;
    }

    /// OWNER ///

    function setPaused(bool _setPaused) external onlyOwner {
        _setPaused ? _pause() : _unpause();
    }

    function setAntiBotFee(uint256 _newFee) external onlyOwner {
        antiBotFee = _newFee;
    }

    function setDuration(uint256 _newDuration) external onlyOwner {
        duration = _newDuration;
    }
}