// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {RunningGameArt} from "@src/modules/RunningGameArt.sol";
import {ptr, isValidPointer, createPointer, DLL, DoublyLinkedListLib} from "@dll/DoublyLinkedList.sol";

/// @dev also need to randomise positions at each lap too, do later, hard tbh
/// Also a winners and losers array per lap?

contract RunningGame is ERC721, Ownable, ReentrancyGuard, RunningGameArt {
    using DoublyLinkedListLib for DLL;

    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @notice The current game status of this contract.
    ///         Pending: Minting not started (just deployed/just settled last game).
    ///         InMint:  Accepting new mints.
    ///         InRace:  Race underway, not accepting new mints.    
    GameStatus public status;

    /// @notice The time (in seconds) minting for each round is open.
    uint256 public mintingTime;
    
    /// @notice The time (in seconds) for each lap.
    uint256 public lapTime;

    /// @notice The total number of laps for each race.
    /// @dev if modifiable, ensure not 0?
    uint256 public lapTotal;

    /// @notice The percentage of mint funds used to buy back and burn BBITS tokens.
    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    /// @notice The total supply of NFTs minted across all games.
    uint256 public totalSupply;

    /// @notice The price to mint an NFT and enter a game.
    uint256 public mintFee;
    
    /// @notice The current Race Id.
    /// @dev    This is also the total number of races held by this contract.
    ///         Skips zero
    uint256 public raceCount;

    /// @notice The Lap Id for the current race.
    /// @dev    The lap count is reset to 0 after each race.
    uint256 public lapCount;

    /// @dev    Race Id => Race Information
    /// @dev must build getter functions for this
    mapping(uint256 => Race) private race;

    /// @dev value Ptr => value
    mapping(ptr => uint256) private runners;

    /// @dev used for ptr generation
    uint64 private counter;

    constructor(address _owner, address _burner) ERC721("Running Game", "RG") Ownable(_owner) {
        burner = Burner(_burner);
        mintingTime = 22.5 hours;
        lapTime = 10 minutes;
        lapTotal = 6;
        status = GameStatus.Pending;
        burnPercentage = 2000;
        mintFee = 0.001 ether;
    }

    receive() external payable {}

    function mint() external payable nonReentrant {
        if (status != GameStatus.InMint) revert WrongStatus();
        if (msg.value < mintFee) revert InsufficientETHPaid();

        /// Burn some bbits
        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        burner.burn{value: burnAmount}(0);
        
        /// Update race info
        ptr newPtr = _createPtrForRunner(totalSupply);
        race[raceCount].positions.push(newPtr);

        /// Mint NFT
        //_setArt();
        _mint(msg.sender, totalSupply++);
    }
    
    function boost(uint256 _tokenId) external nonReentrant {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (ownerOf(_tokenId) != msg.sender) revert NotNFTOwner();

        /// get node ptr
        (ptr node,) = race[raceCount].positions.find(_matchesRunner, abi.encode(_tokenId));
        if (!isValidPointer(node)) revert InvalidNode();

        /// remove node
        race[raceCount].positions.remove(node);

        /// make it the head
        race[raceCount].positions.insertBefore(race[raceCount].positions.head, _createPtrForRunner(_tokenId));
    }

    /// OWNER ///

    function startGame() external onlyOwner {
        if (status != GameStatus.Pending) revert WrongStatus();
        race[++raceCount].startedAt = block.timestamp;
        status = GameStatus.InMint;
        emit GameStarted(raceCount - 1, block.timestamp);
    }

    function startNextLap() external onlyOwner {
        if (status == GameStatus.Pending) revert WrongStatus();
        if (status == GameStatus.InMint) {
            /// First lap
            if (block.timestamp - race[raceCount].startedAt < mintingTime) revert MintingStillActive();
            status = GameStatus.InRace;
            _recordPositions(raceCount, lapCount++);
            race[raceCount].laps[lapCount].startedAt = block.timestamp;
        } else {
            /// Laps 2 - final
            if (block.timestamp - race[raceCount].laps[lapCount].startedAt < lapTime) revert LapStillActive();
            if (lapCount == lapTotal) revert IsFinalLap();
            race[raceCount].laps[lapCount].endedAt = block.timestamp;
            _recordPositions(raceCount, lapCount++);
            race[raceCount].laps[lapCount].startedAt = block.timestamp;
            /// @dev careful of divide by zero here
            uint256 numberToEminate = (race[raceCount].positions.length / lapTotal);
            _eliminateRunners(numberToEminate);
        }
        emit LapStarted(raceCount, lapCount, block.timestamp);
    }

    function finishGame() external onlyOwner {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (lapCount != lapTotal) revert FinalLapNotReached();
        if (block.timestamp - race[raceCount].laps[lapCount].startedAt < lapTime) revert LapStillActive();
        race[raceCount].laps[lapCount].endedAt = block.timestamp;
        _recordPositions(raceCount, lapCount);
        lapCount = 0;

        /// Get winner and pay them
        ptr node = race[raceCount].positions.head;
        uint256 tokenIdOfWinner = _valueAtNode(node);
        address winner = _ownerOf(tokenIdOfWinner);
        uint256 prize = address(this).balance;

        (bool s,) = winner.call{value: prize}("");
        if (!s) revert TransferFailed();

        /// Save game state
        race[raceCount].prize = prize;
        race[raceCount].winner = tokenIdOfWinner;
        status = GameStatus.Pending;

        emit GameEnded(raceCount, block.timestamp);
    }

    /// SETTINGS ///

    function setBurnPercentage(uint256 _newBurnPercentage) external onlyOwner {
        if (_newBurnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _newBurnPercentage;
    }

    function setMintingTime(uint256 _newMintingTime) external onlyOwner {
        if (_newMintingTime < 1 hours) revert InvalidSetting();
        mintingTime = _newMintingTime;
    }

    function setLapTime(uint256 _newLapTime) external onlyOwner {
        if (_newLapTime < 1 minutes) revert InvalidSetting();
        lapTime = _newLapTime;
    }

    function setLapTotal(uint256 _newLapTotal) external onlyOwner {
        if (_newLapTotal == 0) revert InvalidSetting();
        lapTotal = _newLapTotal;
    }

    /// INTERNAL ///

    function _recordPositions(uint256 _raceCount, uint256 _lapCount) internal {
        ptr node = race[_raceCount].positions.head;
        while (isValidPointer(node)) {
            race[_raceCount].laps[_lapCount].positionsAtLapEnd.push(_valueAtNode(node));
            node = race[raceCount].positions.nextAt(node);
        }
    }

    function _eliminateRunners(uint256 _numberToEliminate) internal {
        uint256 i;
        while (i < _numberToEliminate) {
            race[raceCount].positions.pop();
            i++;
        }
    }

    function _matchesRunner(ptr _node, uint64, bytes memory _data) internal view returns (bool) {
        return _valueAtNode(_node) == abi.decode(_data, (uint256));
    }

    /// DOUBLY LINKED LIST ///

    function _createPtrForRunner(uint256 _runner) internal returns (ptr newPtr) {
        newPtr = createPointer(++counter);
        runners[newPtr] = _runner;
    }

    function _valueAtNode(ptr _ptr) internal view returns (uint256) {
        ptr valuePtr = race[raceCount].positions.valueAt(_ptr);
        return runners[valuePtr];
    }

    /// VIEW ///

    /*
    function getRace(uint256 _raceId) external view returns (Race memory) {
        /// is valid race Id
    }

    function getLap() external view returns (Lap memory) {

    }

    function getLineUp() external view returns (uint256[] memory) {
    
    }

    */

    /// @notice Retrieves the URI for a given token ID.
    /// @param  tokenId The ID of the token to retrieve the URI for.
    /// @return The URI string for the token's metadata.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _draw(tokenId);
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}
