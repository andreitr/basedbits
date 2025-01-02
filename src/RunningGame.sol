// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {RunningGameArt} from "@src/modules/RunningGameArt.sol";
import {LibLinkedList, LibLinkedListNode, data_ptr, node_ptr, LL} from "@mll/MemoryLinkedList.sol";

/// @dev lots of bugs in this
///      shouldn't have used a memory only library kek
contract RunningGame is ERC721, Ownable, ReentrancyGuard, RunningGameArt {
    using LibLinkedListNode for node_ptr;
    using LibLinkedList for LL;

    LL public positions;

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

    /// @dev events in interface

    constructor(address _owner, address _burner) ERC721("Running Game", "RG") Ownable(_owner) {
        burner = Burner(_burner);
        mintingTime = 22.5 hours;
        lapTime = 10 minutes;
        lapTotal = 6;
        status = GameStatus.Pending;
        burnPercentage = 2000;
        mintFee = 0.001 ether;
        totalSupply = 1;
    }

    receive() external payable {}

    function mint() external payable nonReentrant {
        if (status != GameStatus.InMint) revert WrongStatus();
        if (msg.value < mintFee) revert InsufficientETHPaid();

        /// Burn some bbits
        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        burner.burn{value: burnAmount}(0);

        /// keep rest for winner
        /// @dev don't need to bother updating state, can just use balance
        
        /// Update race info
        race[raceCount].entries++;
        Runner storage runner = Runner({
            tokenId: totalSupply
        });
        //race[raceCount].positions.push(_toDataPtr(runner));
        positions.push(_toDataPtr(runner));

        /// Mint NFT
        //_setArt();
        _mint(msg.sender, totalSupply++);
    }

    function getPositionsLength() external view returns (uint256) {
        return positions.length;
    }
    
    /// @dev this is broken
    function boost(uint256 _tokenId) external nonReentrant {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (ownerOf(_tokenId) != msg.sender) revert NotNFTOwner();

        /// get node and index
        (node_ptr node, uint256 idx) = race[raceCount].positions.find(_matchesRunner, abi.encode(_tokenId));
        node; /// @dev delete later
        idx;
        /// remove node
        ///race[raceCount].positions.at(idx)
        race[raceCount].positions.remove(node);
        /// make it the head
        race[raceCount].positions.insertBefore(race[raceCount].positions.head, _toDataPtr(Runner(_tokenId)));
    }

    /// OWNER ///

    function startGame() external onlyOwner {
        if (status != GameStatus.Pending) revert WrongStatus();
                
        race[++raceCount].startedAt = block.timestamp;
        status = GameStatus.InMint;
        
        /// some event emission
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

            /// @dev this is broken too
            ///(race[raceCount].entries / lapTotal) - 1
            //_eliminateRunners(1);
        }

        /// event emission
    }

    function finishGame() external onlyOwner {
        if (status != GameStatus.InRace) revert WrongStatus();
        if (lapCount != lapTotal) revert FinalLapNotReached();
        if (block.timestamp - race[raceCount].laps[lapCount].startedAt < lapTime) revert LapStillActive();
        race[raceCount].laps[lapCount].endedAt = block.timestamp;
        _recordPositions(raceCount, lapCount);
        lapCount = 0;

        /// Get winner and pay them
        node_ptr node = race[raceCount].positions.head;
        uint256 tokenIdOfWinner = _fromDataPtr(node.data()).tokenId;
        address winner = _ownerOf(tokenIdOfWinner);

        (bool s,) = winner.call{value: address(this).balance}("");
        if (!s) revert TransferFailed();

        /// Reset whatever else needs resetting

        /// Event emissions
    }

    function setBurnPercentage(uint256 _newBurnPercentage) external onlyOwner {
        if (_newBurnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _newBurnPercentage;
    }

    /// INTERNAL ///
    
    function _recordPositions(uint256 _raceCount, uint256 _lapCount) internal {
        node_ptr node = race[_raceCount].positions.head;
        while (node.isValid()) {
            race[_raceCount].laps[_lapCount].positionsAtLapEnd.push(_fromDataPtr(node.data()).tokenId);
            node = node.next();
        }
    }

    /// @dev CHECK THIS WORKS
    function _eliminateRunners(uint256 _numberToEliminate) internal {
        uint256 i;
        while (i < _numberToEliminate) {
            race[raceCount].positions.pop();
            i++;
        }
    }

    /// LINKED LIST ///

    function _fromDataPtr(data_ptr ptr) private pure returns (Runner storage data) {
        uint256 pointer = uint256(data_ptr.unwrap(ptr)); 
        assembly {
            data := pointer
        }
    }

    function _toDataPtr(Runner storage data) private pure returns (data_ptr ptr) {
        uint256 pointer;
        assembly {
            pointer := data
        }
        require(pointer < 2**48, "Pointer exceeds 48 bits");
        ptr = data_ptr.wrap(uint48(pointer));
    }

    function _matchesRunner(node_ptr node, uint256, bytes memory callerData) private pure returns (bool) {
        uint256 needle = abi.decode(callerData, (uint256));
        return _fromDataPtr(node.data()).tokenId == needle;
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

    Also a winners and losers array per lap
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
