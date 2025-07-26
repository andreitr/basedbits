// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {BaseRaceArt} from "@src/modules/BaseRaceArt.sol";
import {ptr, isValidPointer, createPointer, DLL, DoublyLinkedListLib} from "@dll/DoublyLinkedList.sol";

/// @title  Base Race
/// @notice This contract manages a race between NFT runners. Users can mint NFTs to participate in races,
///         boost their runners, and win the prize pool of deposited ETH.
/// @dev    DEFAULT_ADMIN_ROLE - Settings and Admin role authority
///         ADMIN_ROLE         - Race progression
/// NOTE    !!! STILL LACKS ART !!!
contract BaseRace is ERC721, AccessControl, ReentrancyGuard, BaseRaceArt {
    using DoublyLinkedListLib for DLL;

    /// @notice Admin role that controls the race stages.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

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

    /// @dev    Race Id => Race Information
    mapping(uint256 => Race) private race;

    /// @dev    Value Ptr => Value
    mapping(ptr => uint256) private runners;

    /// @dev    RaceId => User = Entries
    mapping(uint256 => mapping(address => uint256[])) private raceEntriesPerUser;

    /// @dev    Used for ptr generation to prevent collisions.
    uint64 private counter;

    constructor(address _owner, address _admin, address _burner) ERC721("Base Race", "BRCE") {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, _admin);
        burner = Burner(_burner);
        mintingTime = 22.5 hours;
        lapTime = 10 minutes;
        status = GameStatus.Pending;
        burnPercentage = 2000;
        mintFee = 0.001 ether;
    }

    receive() external payable {}

    /// @notice This function allows any user to mint an NFT and enter into the forthcoming race.
    /// @dev    Must pay the mintFee in ETH.
    ///         Game status must be in the `InMint` stage.
    function mint() external payable nonReentrant {
        if (status != GameStatus.InMint) revert WrongStatus();
        if (msg.value < mintFee) revert InsufficientETHPaid();
        /// Burn some BBITS
        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        burner.burn{value: burnAmount}(0);
        /// Add runner to race
        ptr newPtr = _createPtrForRunner(totalSupply);
        race[raceCount].positions.push(newPtr);
        race[raceCount].prize = address(this).balance;
        race[raceCount].entries++;
        raceEntriesPerUser[raceCount][msg.sender].push(totalSupply);

        uint256 numEntries = race[raceCount].entries;
        race[raceCount].lapTotal = _calcLaps(numEntries);

        /// Mint
        //_setArt();
        _mint(msg.sender, totalSupply++);
    }

    /// @notice This function allows any user who has an NFT Runner in the current race to boost their Runner
    ///         to the front of the pack.
    /// @param  _tokenId The token Id of the NFT Runner to be boosted.
    function boost(uint256 _tokenId) external nonReentrant {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (ownerOf(_tokenId) != msg.sender) revert NotNFTOwner();

        if (race[raceCount].laps[race[raceCount].lapCount].boosted[_tokenId]) revert HasBoosted();
        race[raceCount].laps[race[raceCount].lapCount].boosted[_tokenId] = true;

        /// Get node ptr, remove it, and make it head
        (ptr node,) = race[raceCount].positions.find(_matchesRunner, abi.encode(_tokenId));
        if (!isValidPointer(node)) revert InvalidNode();
        race[raceCount].positions.remove(node);
        race[raceCount].positions.insertBefore(race[raceCount].positions.head, _createPtrForRunner(_tokenId));
    }

    /// RACE ///

    /// @notice This function allows the admin to start the next game.
    /// @dev    Game status must be in the `Pending` stage.
    function startGame() external onlyRole(ADMIN_ROLE) {
        if (status != GameStatus.Pending) revert WrongStatus();
        race[++raceCount].startedAt = block.timestamp;
        race[raceCount].lapCount = 0;
        status = GameStatus.InMint;
        emit GameStarted(raceCount, block.timestamp);
    }

    /// @notice This function allows the admin to start the next lap in the current game.
    /// @dev    Game status must be in either `InMint` or `InRace` stage.
    ///         Records runner positions for the end of the previous lap.
    ///         Eliminates the slowest runners at the end of each lap.
    function startNextLap() external onlyRole(ADMIN_ROLE) {
        if (status == GameStatus.Pending) revert WrongStatus();

        if (status == GameStatus.InMint) {
            if (block.timestamp - race[raceCount].startedAt < mintingTime) revert MintingStillActive();
            status = GameStatus.InRace;
        } else {
            if (block.timestamp - race[raceCount].laps[race[raceCount].lapCount].startedAt < lapTime) {
                revert LapStillActive();
            }
        }

        // Prevent extra laps
        if (race[raceCount].lapCount >= race[raceCount].lapTotal) revert IsFinalLap();

        // Finish current lap
        if (race[raceCount].lapCount > 0) {
            race[raceCount].laps[race[raceCount].lapCount].endedAt = block.timestamp;
            _updateStorageArrays();
        }

        // Start next lap
        race[raceCount].lapCount++;
        race[raceCount].laps[race[raceCount].lapCount].startedAt = block.timestamp;
        race[raceCount].laps[race[raceCount].lapCount].eliminations =
            _calcEliminationsPerLap(race[raceCount].entries, race[raceCount].lapCount);

        _shufflePositions();
        emit LapStarted(raceCount, race[raceCount].lapCount, block.timestamp);
    }

    /// @notice This function allows the admin to finish the current game.
    /// @dev    Game status must be in the `InRace` stage.
    ///         Awards the race winner, which is the NFT at the head of the DLL positions list.
    function finishGame() external onlyRole(ADMIN_ROLE) {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (race[raceCount].lapCount != race[raceCount].lapTotal) revert FinalLapNotReached();
        if (block.timestamp - race[raceCount].laps[race[raceCount].lapCount].startedAt < lapTime) {
            revert LapStillActive();
        }
        /// Finish current and final lap
        race[raceCount].laps[race[raceCount].lapCount].endedAt = block.timestamp;
        _updateStorageArrays();

        /// Get winner and pay them
        ptr node = race[raceCount].positions.head;
        uint256 tokenIdOfWinner;
        if (isValidPointer(node)) {
            tokenIdOfWinner = _valueAtNode(node);
            address winner = _ownerOf(tokenIdOfWinner);
            (bool s,) = winner.call{value: address(this).balance}("");
            if (!s) revert TransferFailed();
        }
        /// Save game state
        race[raceCount].winner = tokenIdOfWinner;
        race[raceCount].endedAt = block.timestamp;
        status = GameStatus.Pending;
        emit GameEnded(raceCount, block.timestamp);
    }

    /// SETTINGS ///

    function setBurnPercentage(uint256 _newBurnPercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newBurnPercentage > 10_000) revert InvalidSetting();
        burnPercentage = _newBurnPercentage;
    }

    function setMintFee(uint256 _newMintFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newMintFee < 10_000) revert InvalidSetting();
        mintFee = _newMintFee;
    }

    function setMintingTime(uint256 _newMintingTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newMintingTime < 1 hours) revert InvalidSetting();
        mintingTime = _newMintingTime;
    }

    function setLapTime(uint256 _newLapTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newLapTime < 1 minutes) revert InvalidSetting();
        lapTime = _newLapTime;
    }

    /// INTERNAL ///

    /// Function to determine the number of laps (max 6) based on entries
    function _calcLaps(uint256 numEntries) internal pure returns (uint256) {
        if (numEntries <= 2) {
            return 1; // Single lap for 1v1 scenarios
        }

        uint256 finalLapPlayers = _calcFinalLapPlayers(numEntries);
        uint256 totalEliminations = numEntries - finalLapPlayers;

        // Ensure at least 1 elimination per lap, but do not force 6 laps unnecessarily
        uint256 laps = totalEliminations < 6 ? totalEliminations : 6;
        return laps;
    }

    // Function to determine the number of players in the final lap
    function _calcFinalLapPlayers(uint256 numEntries) internal pure returns (uint8) {
        return numEntries > 32 ? 7 : numEntries > 16 ? 5 : numEntries > 8 ? 3 : 2;
    }

    // Function to determine eliminations for a specific lap
    function _calcEliminationsPerLap(uint256 numEntries, uint256 lapId) internal view returns (uint256) {
        uint256 totalLaps = _calcLaps(numEntries);
        uint256 finalLapPlayers = _calcFinalLapPlayers(numEntries);
        uint256 totalEliminations = numEntries - finalLapPlayers;

        // Ensure eliminations per lap are distributed evenly
        uint256 baseEliminations = totalEliminations / totalLaps; // Ceil division

        // Ensure every lap has at least 1 elimination and stops at final lap
        uint256 eliminationsForLap = lapId < totalLaps ? baseEliminations : (numEntries - finalLapPlayers);

        // If it's the final lap, eliminate all but one player (the winner)
        if (lapId == totalLaps) {
            uint256 currentRunners = race[raceCount].positions.length;
            eliminationsForLap = currentRunners - 1;
        }

        return eliminationsForLap;
    }

    function _updateStorageArrays() internal {
        uint256 tokenId;
        uint256 numberToEliminate = race[raceCount].laps[race[raceCount].lapCount].eliminations;

        // Store current positions before eliminations
        uint256 length = race[raceCount].positions.length;
        uint256[] storage positionsArray = race[raceCount].laps[race[raceCount].lapCount].positions;
        ptr ptrPosition = race[raceCount].positions.head;
        for (uint256 j; j < length; j++) {
            tokenId = _valueAtNode(ptrPosition);
            positionsArray.push(tokenId);
            ptrPosition = race[raceCount].positions.nextAt(ptrPosition);
        }

        // Remove only exact number of eliminations per lap
        for (uint256 i; i < numberToEliminate; i++) {
            ptr node = race[raceCount].positions.tail;
            if (!isValidPointer(node)) break;

            tokenId = _valueAtNode(node);
            race[raceCount].positions.pop();
        }
    }

    function _shufflePositions() internal {
        uint256 length = race[raceCount].positions.length;
        if (length < 2) return;
        /// Record tokenIds in array
        uint256[] memory tokenIds = new uint256[](length);
        ptr ptrPosition = race[raceCount].positions.head;
        for (uint256 a; a < length; a++) {
            tokenIds[a] = _valueAtNode(ptrPosition);
            ptrPosition = race[raceCount].positions.nextAt(ptrPosition);
        }
        /// Shuffle array using Fisher-Yates
        uint256 seed;
        uint256 x;
        uint256 temp;
        for (uint256 b = length - 1; b > 0; b--) {
            seed = uint256(keccak256(abi.encode(block.timestamp, b)));
            x = seed % (b + 1);
            temp = tokenIds[b];
            tokenIds[b] = tokenIds[x];
            tokenIds[x] = temp;
        }
        /// Rebuild dll
        race[raceCount].positions.clear();
        ptr newPtr;
        for (uint256 c; c < length; c++) {
            newPtr = _createPtrForRunner(tokenIds[c]);
            race[raceCount].positions.push(newPtr);
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

    /// @notice Returns the race information for a given race ID.
    /// @param  _raceId The ID of the race to retrieve information for.
    /// @return entries The number of entries in the race.
    /// @return startedAt The timestamp when the race started.
    /// @return endedAt The timestamp when the race ended (0 if not finished).
    /// @return lapTotal The total number of laps of the race.
    /// @return lapCount The current lap number of the race.
    /// @return prize The prize pool for the race (outsanding balance of the contract).
    /// @return winner The token ID of the winning runner (0 if not finished).
    function getRace(uint256 _raceId)
        external
        view
        returns (
            uint256 entries,
            uint256 startedAt,
            uint256 endedAt,
            uint256 lapTotal,
            uint256 lapCount,
            uint256 prize,
            uint256 winner
        )
    {
        entries = race[_raceId].entries;
        startedAt = race[_raceId].startedAt;
        endedAt = race[_raceId].endedAt;
        lapTotal = race[_raceId].lapTotal;
        lapCount = race[_raceId].lapCount;
        prize = race[_raceId].prize;
        winner = race[_raceId].winner;
    }

    /// @notice Returns the list of token IDs entered by a user in a given race.
    /// @param  _raceId The ID of the race.
    /// @param  _user The address of the user.
    /// @return entries An array of token IDs representing the user's entries in the race.
    function getRaceEntries(uint256 _raceId, address _user) external view returns (uint256[] memory entries) {
        return raceEntriesPerUser[_raceId][_user];
    }

    /// @notice Returns the lap information for a given race and lap ID.
    /// @param  _raceId The ID of the race.
    /// @param  _lapId The ID of the lap.
    /// @return startedAt The timestamp when the lap started.
    /// @return endedAt The timestamp when the lap ended (0 if not finished).
    /// @return eliminations The number of runners eliminated in this lap.
    /// @return positions An array of token IDs representing the positions of the runners at the end of the lap
    ///         (winners for finished laps, current positions for the active lap).
    function getLap(uint256 _raceId, uint256 _lapId)
        external
        view
        returns (uint256 startedAt, uint256 endedAt, uint256 eliminations, uint256[] memory positions)
    {
        startedAt = race[_raceId].laps[_lapId].startedAt;
        endedAt = race[_raceId].laps[_lapId].endedAt;
        eliminations = race[_raceId].laps[_lapId].eliminations;

        if (_raceId == raceCount && _lapId == race[_raceId].lapCount) {
            // Active lap - get current positions from DLL
            uint256 length = race[_raceId].positions.length;
            positions = new uint256[](length);
            ptr ptrPosition = race[_raceId].positions.head;
            for (uint256 i; i < length; i++) {
                positions[i] = _valueAtNode(ptrPosition);
                ptrPosition = race[_raceId].positions.nextAt(ptrPosition);
            }
        } else {
            // Finished lap - get stored positions
            positions = race[_raceId].laps[_lapId].positions;
        }
    }

    /// @notice Checks if a runner has used their boost in a given lap.
    /// @param  _raceId The ID of the race.
    /// @param  _lapId The ID of the lap.
    /// @param  _tokenId The token ID of the runner.
    /// @return True if the runner has used their boost in the specified lap, false otherwise.
    function isBoosted(uint256 _raceId, uint256 _lapId, uint256 _tokenId) external view returns (bool) {
        return race[_raceId].laps[_lapId].boosted[_tokenId];
    }

    /// @notice Retrieves the URI for a given token ID.
    /// @param  tokenId The ID of the token to retrieve the URI for.
    /// @return The URI string for the token's metadata.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _draw(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}
