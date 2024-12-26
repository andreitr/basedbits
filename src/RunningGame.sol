// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {RunningGameArt} from "@src/modules/RunningGameArt.sol";

/// @dev how do i ensure noon start time? hard, maybe ignore for now
contract RunningGame is ERC721, Ownable, ReentrancyGuard, RunningGameArt {
    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @dev Make mintingTime, LapTime, and LapTotal all modifiable

    /// @notice The time (in seconds) minting for each round is open.
    uint256 public immutable mintingTime;
    
    /// @notice The time (in seconds) for each lap.
    uint256 public immutable lapTime;

    /// @notice The total number of laps for each race.
    /// @dev if modifiable, ensure not 0?
    uint256 public immutable lapTotal;

    /// @notice The current game status of this contract.
    ///         Pending: Minting not started (just deployed/just settled last game).
    ///         InMint:  Accepting new mints.
    ///         InRace:  Race underway, not accepting new mints.    
    GameStatus public status;

    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    uint256 public totalSupply;

    uint256 public mintFee;
    
    /// @notice The current Race Id.
    /// @dev    This is also the total number of races held by this contract.
    ///         Skips zero
    uint256 public raceCount;

    /// @notice The Lap Id for the current race.
    /// @dev    The lap count is reset to 0 after each race.
    uint256 public lapCount;

    /// @dev    Race Id => Race Information
    mapping(uint256 => Race) public race;

    /// @dev    Race Id => Lap Id => Lap Information
    mapping(uint256 => mapping(uint256 => Lap)) public lap;

    /// @dev events here

    constructor(address _owner, address _burner) ERC721("Running Game", "RG") Ownable(_owner) {
        burner = Burner(_burner);
        mintingTime = 22.5 hours;
        lapTime = 10 minutes;
        lapTotal = 6;
        status = GameStatus.Pending;
        burnPercentage = 2000;
        mintFee = 0.001 ether;
    }

    //receive() external payable {}

    function mint() external payable nonReentrant {
        if (status != GameStatus.InMint) revert WrongStatus();
        if (msg.value < mintFee) revert InsufficientETHPaid();

        ///tokenIdToRaceId[totalSupply] = raceCount;

        /// some logic about the set in each race?

        _mint(msg.sender, totalSupply++);
        //_setArt();

        /// some logic about updating status if mint time exceeded?
    }

    function boost(uint256 _tokenId) external nonReentrant {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (ownerOf(_tokenId) != msg.sender) revert NotNFTOwner();

        /// Find the NFT's position - AAAAHHHHHHHHHH
        uint256 index = ~uint256(0);
        uint256[] memory positions = lap[raceCount][lapCount].positions;
        uint256 length = positions.length;
        for (uint256 i; i < length; i++) {
            if (_tokenId == positions[i]) {
                index = i;
                break;
            }
        }
        if (index == ~uint256(0)) revert NotInRace();

        /// Boost given index

        /// Move winner to OG index position

        /// This might not work that well, I think the red-black tree might be the way to go

        uint256 currentWinner = lap[raceCount][lapCount].positions[0];

        lap[raceCount][lapCount].positions[0] = _tokenId;

        //lap[raceCount][lapCount].positions[index]
    }

    /// OWNER ///

    function startGame() external onlyOwner {
        if (status != GameStatus.Pending) revert WrongStatus();
                
        race[++raceCount].startedAt = block.timestamp;
        status = GameStatus.InMint;
        

        /// some event emission
    }

    /// @dev should make the number of laps modifiable too, he'll want that for sure 

    /// @dev maybe re-think this, messy
    function startNextLap() external onlyOwner {
        if (status == GameStatus.Pending) revert WrongStatus();
        
        /// @dev lap accounting

        if (status == GameStatus.InMint) {
            /// First lap
            if (block.timestamp - race[raceCount].startedAt < mintingTime) revert MintingStillActive();
            status = GameStatus.InRace;
            lapCount = 1;
            lap[raceCount][lapCount].startedAt = block.timestamp;
            /// Some other logic?
        } else {
            /// Laps 2-final
            if (block.timestamp - lap[raceCount][lapCount].startedAt < lapTime) revert LapStillActive();
            if (lapCount == lapTotal) revert IsFinalLap();
            lap[raceCount][lapCount].endedAt = block.timestamp;
            lapCount++; /// @dev can condense later
            lap[raceCount][lapCount].startedAt = block.timestamp;
        }

        /// @dev position accounting

        /// some logic about the elimination

        /// event emission
    }

    function finishGame() external onlyOwner {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (lapCount != lapTotal) revert FinalLapNotReached();
        if (block.timestamp - lap[raceCount][lapCount].startedAt < lapTime) revert LapStillActive();

        lap[raceCount][lapCount].endedAt = block.timestamp;
        lapCount = 0;

        /// Get winner

        /// Pay winner

        /// Reset whatever else needs resetting

        /// Event emissions
    }

    function setBurnPercentage(uint256 _newBurnPercentage) external onlyOwner {
        if (_newBurnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _newBurnPercentage;
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
