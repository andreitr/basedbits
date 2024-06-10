// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IBBitsCheckIn} from "./interfaces/IBBitsCheckIn.sol";
import {IBBitsRaffle} from "./interfaces/IBBitsRaffle.sol";

/// @title  Based Bits Raffle
/// @notice This contract allows users to participate in raffles to win NFTs from the Based Bits collection.
/// @dev    The contract operates on a loop, cycling through the PendingRaffle, InRaffle, and PendingSettlement
///         stages continuously. The Owner retains admin rights over pausability, the antiBotFee, and the
///         duration of raffle entry periods. Randomness for winners is achieved on-chain via a commit-reveal
///         of a random seed. Due to expiry of the blockhash() method, the random seed may be re-generated for a
///         fee. The most recent user to set the random seed is repaid after a successful raffle settlement.  
contract BBitsRaffle is IBBitsRaffle, Ownable, ReentrancyGuard, Pausable {
    /// @notice Based Bits NFT collection.
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

    /// @dev The Block Number Setter, who is repaid the antiBotFee. 
    address private lastBlockNumberSetter;

    /// @notice A mapping from raffle ids to raffle info.
    mapping(uint256 => Raffle) public idToRaffle;

    /// @notice A mapping to track addresses that have entered any given raffle.
    /// @dev    raffleId => address => entered
    mapping(uint256 => mapping(address => bool)) public hasEnteredRaffle;

    /// @notice A mapping to track the number of free entries for any given raffle.
    mapping(uint256 => uint256) public raffleFreeEntryCount;

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

    /// @notice This function allows anyone to deposit Based Bits NFTs to be raffled.
    /// @param  _tokenIds An array of token IDs to deposit.
    /// NOTE    The user must approve this contract to move the NFTs prior to calling this function.
    /// @dev    Can deposit under any contract status.
    function depositBasedBits(uint256[] calldata _tokenIds) external nonReentrant whenNotPaused {
        uint256 length = _tokenIds.length;
        if (length == 0) revert DepositZero();
        uint256 tokenId;
        SponsoredPrize memory newSponsoredPrize;
        for (uint256 i; i < length; ++i) {
            tokenId = _tokenIds[i];
            collection.transferFrom(msg.sender, address(this), tokenId);
            newSponsoredPrize = SponsoredPrize({
                tokenId: tokenId,
                sponsor: msg.sender
            });
            prizes.push(newSponsoredPrize);
            emit BasedBitsDeposited(msg.sender, tokenId);
        }
    }

    /// START RAFFLE ///

    /// @notice This function allows any user to initiate the next raffle. 
    /// @dev    Must be in PendingRaffle status. 
    ///         There must be collection NFTs to raffle.
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

    /// @notice This function allows eligible users to enter into the current raffle for free.
    /// @dev    Must be in InRaffle status.
    ///         Must be eligible for free entry.
    function newFreeEntry() external nonReentrant whenNotPaused {
        if (!isEligibleForFreeEntry(msg.sender)) revert NotEligibleForFreeEntry();
        ++raffleFreeEntryCount[getCurrentRaffleId()];
        _newEntry();
    }

    /// @notice This function allows anyone to enter into the current raffle.
    /// @dev    Must be in InRaffle status. 
    ///         Must pay the antiBotFee.
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

    /// @notice This function allows anyone to set the random seed necessary to settle the current raffle.
    /// @dev    Status can be either InRaffle or PendingSettlement to allow for re-rolling seed.
    ///         Must be called after the current raffle entry duration has expired.
    ///         Must pay the antiBotFee.
    function setRandomSeed() external payable nonReentrant whenNotPaused {
        if (status == RaffleStatus.PendingRaffle) revert WrongStatus();
        uint256 currentRaffleId = getCurrentRaffleId();
        Raffle storage currentRaffle = idToRaffle[currentRaffleId];
        if (block.timestamp - currentRaffle.startedAt < duration) revert RaffleOnGoing();
        if (msg.value != antiBotFee) revert MustPayAntiBotFee();
        lastBlockNumberSetter = msg.sender;
        futureBlockNumber = block.number + 1;
        status = RaffleStatus.PendingSettlement;
        emit RandomSeedSet(currentRaffleId, futureBlockNumber);
    }

    /// @notice This function allows anyone to settle the current raffle. Either a winner is chosen or the raffle
    ///         is reset. Additionally, the most recent seed setter is repaid the antiBotFee, and all remaining
    ///         contract funds are sent to the sponsor of the raffle (the user who initially deposited the NFT
    ///         that was awarded to the winner).
    /// @dev    Must be in PendingSettlement status. 
    ///         Must not check return values from the calls to lastBlockNumberSetter and sponsor to ensure the
    ///         function can not be soft-locked. Also prevents griefing abuse.
    function settleRaffle() external nonReentrant whenNotPaused {
        if (status != RaffleStatus.PendingSettlement) revert WrongStatus();
        bytes32 blockHash = blockhash(futureBlockNumber);
        if (blockHash == bytes32(0)) revert SeedMustBeReset();
        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(futureBlockNumber, blockHash)));
        uint256 currentRaffleId = getCurrentRaffleId();
        Raffle storage currentRaffle = idToRaffle[currentRaffleId];
        uint256 entriesLength = currentRaffle.entries.length;
        lastBlockNumberSetter.call{value: antiBotFee}("");
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
            sponsor.call{value: address(this).balance}("");
            emit RaffleSettled(currentRaffleId, winner, tokenId);
        }
        status = RaffleStatus.PendingRaffle;
    }

    /// VIEW ///
    
    /// @notice A view function that returns the current raffle Id.
    /// @dev    There is no raffle zero.
    function getCurrentRaffleId() public view returns (uint256) {
        return count - 1; 
    }

    /// @notice A view function that returns the total number of entries for any given raffle.
    function getRaffleEntryNumber(uint256 _raffleId) public view returns (uint256) {
        return idToRaffle[_raffleId].entries.length;
    }

    /// @notice A view function that returns the entry address for any raffle given raffle and entry position.
    function getRaffleEntryByIndex(uint256 _raffleId, uint256 _index) public view returns (address) {
        if (_index >= getRaffleEntryNumber(_raffleId)) revert IndexOutOfBounds();
        return idToRaffle[_raffleId].entries[_index];
    }

    /// @notice A view function that returns whether any given user is eligible for free entry into the current 
    ///         raffle.
    function isEligibleForFreeEntry(address _user) public view returns (bool) {
        if (collection.balanceOf(_user) <= raffleFreeEntryCount[getCurrentRaffleId()]) return false;
        (, uint16 streak,) = checkIn.checkIns(_user);
        if (streak < 2) return false;
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