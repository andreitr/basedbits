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
    uint256 public raffleCount;

    /// @notice Length of time that a raffle lasts.
    uint256 public rafflePeriod;

    /// @notice An fee that must be paid on some functions to discourage botting or abuse.
    uint256 public antiBotFee;

    /// @dev The value used to derive randomness when settling the raffle.
    uint256 private futureBlockNumber;

    /// @notice A mapping from raffle ids to raffle info.
    mapping(uint256 => Raffle) public idToRaffle;

    /// @notice A mapping to track entries for any given raffle.
    /// @dev raffleId => address => entered
    mapping(uint256 => mapping(address => bool)) public hasEnteredRaffle;

    /// @notice An array of token ids and corresponding sponsors that are held by the contract.
    SponsoredPrize[] public prizes;

    constructor(address _owner, IERC721 _collection, IBBitsCheckIn _checkIn) Ownable(_owner) {
        status = RaffleStatus.PendingRaffle;
        collection = _collection;
        checkIn = _checkIn;
        rafflePeriod = 1 days;
        antiBotFee = 0.0001 ether;
        raffleCount = 1; /// @dev start it at 1 to make logic nicer
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
            sponsoredPrize: prizes[prizesLength - 1]
        });
        idToRaffle[raffleCount++] = newRaffle; /// @dev check raffleCount is incremented properly here
        /// @dev Doesn't pop the prizes array yet incase there are no entries, does it at settlement

        status = RaffleStatus.InRaffle;

        emit NewRaffleStarted(getCurrentRaffleId());
    }

    /// ENTRIES ///

    function newFreeEntry() external nonReentrant whenNotPaused {
        if (!isEligibleForFreeEntry(msg.sender)) revert NotEligibleForFreeEntry();

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

        if (block.timestamp - currentRaffle.startedAt > rafflePeriod) revert RaffleExpired();
        
        if (hasEnteredRaffle[currentRaffleId][msg.sender]) revert AlreadyEnteredRaffle();

        hasEnteredRaffle[currentRaffleId][msg.sender] = true;

        currentRaffle.entries.push(msg.sender);

        emit RaffleEntered(currentRaffleId, msg.sender);
    }

    /// SETTLEMENT ///

    function setRandomSeed() external payable nonReentrant whenNotPaused {
        /// @dev Status can be either InRaffle or PendingSettlement to allow for re-rolling seed
        if (status == RaffleStatus.PendingRaffle) revert WrongStatus();

        uint256 currentRaffleId = getCurrentRaffleId();

        Raffle storage currentRaffle = idToRaffle[currentRaffleId];

        if (block.timestamp - currentRaffle.startedAt < rafflePeriod) revert RaffleOnGoing();

        if (msg.value != antiBotFee) revert MustPayAntiBotFee();

        futureBlockNumber = block.number + 1;

        status = RaffleStatus.PendingSettlement;

        emit RandomSeedSet(currentRaffleId, futureBlockNumber);
    }

    function settleRaffle() external nonReentrant whenNotPaused {
        if (status != RaffleStatus.PendingSettlement) revert WrongStatus();

        /// @dev The first clause prevents setting the seed and settling the raffle in the same block
        if (block.number < futureBlockNumber || block.number - futureBlockNumber >= 255) revert SeedMustBeReset();

        uint256 pseudoRandom = uint256(keccak256(abi.encodePacked(futureBlockNumber, blockhash(futureBlockNumber))));

        uint256 currentRaffleId = getCurrentRaffleId();

        Raffle storage currentRaffle = idToRaffle[currentRaffleId];

        uint256 entriesLength = currentRaffle.entries.length;

        if (entriesLength == 0) {
            currentRaffle.settledAt = block.timestamp;
            emit RaffleSettled(currentRaffleId, address(0), 0);
        } else {
            prizes.pop(); /// @dev Only pops the prize array if there are entries

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
        return raffleCount - 1; 
    }

    function isEligibleForFreeEntry(address _user) public view returns (bool) {
        if (collection.balanceOf(_user) == 0) return false;
        
        (uint256 _lastCheckIn,,) = checkIn.checkIns(_user);
        if (block.timestamp - _lastCheckIn > 2 days) revert HasNotCheckedInRecently();
        
        return true;
    }

    /// OWNER ///

    function setPaused(bool _isPaused) external onlyOwner {
        _isPaused ? _pause() : _unpause();
    }

    function setAntiBotFee(uint256 _newFee) external onlyOwner {
        antiBotFee = _newFee;
    }

    function setRafflePeriod(uint256 _newRafflePeriod) external onlyOwner {
        rafflePeriod = _newRafflePeriod;
    }
}