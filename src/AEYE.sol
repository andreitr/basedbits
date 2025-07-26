// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {ERC1155Supply} from "@src/modules/ERC1155Supply.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/utils/introspection/IERC165.sol";

interface Burner {
    function burn(uint256 _minAmountBurned) external payable;
}

/// @title  AEYE
/// @notice This contract allows users to mint daily NFTs with unique artwork.
/// @dev    The contract operates on admin-initiated cycles, where admins can create new tokens with custom SVG and metadata.
///         The Owner retains admin rights over pausability and the mintPrice.
contract AEYE is ERC1155Supply, Ownable, Pausable, AccessControl, ReentrancyGuard {
    /// @notice The price to mint an NFT.
    uint256 public mintPrice;

    /// @notice The token id of the current NFT.
    uint256 public currentMint;

    /// @notice The artist address that receives a portion of mint fees
    address public immutable artist;

    /// @notice The burner contract that handles buy and burns
    Burner public immutable burner;

    /// @dev    10_000 = 100%
    uint16 public burnPercentage;

    /// @dev    10_000 = 100%
    uint16 public artistPercentage;

    /// @dev    10_000 = 100%
    uint16 public communityPercentage;

    /// @notice A mapping to track addresses that have minted in a given cycle.
    /// @dev    cycleId => address => minted
    mapping(uint256 => mapping(address => bool)) public hasMinted;

    /// @notice A mapping to track user's minting streak
    /// @dev    address => streak
    mapping(address => uint8) public mintingStreak;

    /// @notice A mapping to track total unique minters across all tokens
    /// @dev    address => totalMints
    mapping(address => uint256) public totalMints;

    /// @notice Tracks total number of tokens minted (including multiple mints) per cycle
    mapping(uint256 => uint256) private _totalMintsPerToken;

    /// @notice A mapping to track community rewards for each token
    /// @dev    tokenId => totalCommunityRewards
    mapping(uint256 => uint256) public tokenCommunityRewards;

    /// @notice OpenSea-style contract-level metadata URI
    string public contractMetadataURI;

    // --- Reward snapshot accounting ---
    uint256 private constant PRECISION = 1e18;
    /// @notice Accumulated reward per weight for each token cycle
    mapping(uint256 => uint256) public accRewardPerShare;
    /// @notice Snapshot of each user's weight for each token cycle
    mapping(uint256 => mapping(address => uint256)) public weightSnapshot;
    /// @notice Last token cycle a user has claimed rewards for
    mapping(address => uint256) public lastClaimedToken;

    /// @notice Total summed weight for each cycle (no loops needed at cycle-close)
    mapping(uint256 => uint256) public totalWeightPerCycle;

    /// @notice A mapping to store token metadata
    /// @dev    tokenId => metadata
    mapping(uint256 => TokenMetadata) public tokenMetadata;

    /// @notice Role identifier for admin
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Temporary storage for pending rewards per minter
    uint256 private _pendingRewardsPerMinter;

    struct TokenMetadata {
        string metadata;
        uint256 createdAt;
    }

    error MustPayMintPrice();
    error MetadataNotSet();
    error InvalidPercentage();
    error TransferFailed();
    error NoRewardsToClaim();

    event TokenCreated(uint256 indexed tokenId, string metadata);
    event MetadataUpdated(uint256 indexed tokenId, string newMetadata);
    event PercentagesUpdated(uint256 burnPercentage, uint256 artistPercentage, uint256 communityPercentage);
    event CommunityRewardsClaimed(uint256 indexed tokenId, address indexed user, uint256 amount);

    /// @dev Begins paused to allow owner to add art.
    constructor(address _owner, address _artist, address _burner) ERC1155("") Ownable(_owner) {
        mintPrice = 0.0008 ether;
        artist = _artist;
        burner = Burner(_burner);

        burnPercentage = 2000; // 20%
        artistPercentage = 3000; // 30%
        communityPercentage = 5000; // 50%

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, _owner);

        _pause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Allows the contract to receive ETH payments
    receive() external payable {}

    /// @notice This function provides the core functionality for minting NFTs and transitioning to new cycles.
    function mint() external payable nonReentrant whenNotPaused {
        if (!hasMetadata(currentMint)) revert MetadataNotSet();
        if (msg.value < mintPrice) revert MustPayMintPrice();

        // Update internal state before any external transfers
        _mintEntry();

        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        uint256 artistAmount = (msg.value * artistPercentage) / 10_000;
        uint256 communityAmount = (msg.value * communityPercentage) / 10_000;
        uint256 ownerAmount = msg.value - burnAmount - artistAmount - communityAmount;

        // Send to burner
        if (burnAmount > 0) {
            burner.burn{value: burnAmount}(0);
        }

        // Send to artist
        if (artistAmount > 0) {
            (bool success,) = artist.call{value: artistAmount}("");
            if (!success) revert TransferFailed();
        }

        // Add to community rewards
        if (communityAmount > 0) {
            tokenCommunityRewards[currentMint] += communityAmount;
        }

        // Send remaining to owner
        if (ownerAmount > 0) {
            (bool success,) = owner().call{value: ownerAmount}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @dev Mints the current token to the caller
    function _mintEntry() internal {
        _mint(msg.sender, currentMint, 1, "");
        // Count every token minted, even if same user
        _totalMintsPerToken[currentMint] += 1;

        if (!hasMinted[currentMint][msg.sender]) {
            hasMinted[currentMint][msg.sender] = true;

            // Update streak once per cycle
            if (currentMint > 0 && hasMinted[currentMint - 1][msg.sender]) {
                // Cap streak at 10 days to prevent storage bloat
                if (mintingStreak[msg.sender] < 10) {
                    mintingStreak[msg.sender]++;
                }
            } else {
                mintingStreak[msg.sender] = 1;
            }

            // Snapshot this user's weight for the current cycle and update total weight
            uint256 w = weightOf(msg.sender);
            weightSnapshot[currentMint][msg.sender] = w;
            totalWeightPerCycle[currentMint] += w;
        }
    }

    /// @notice Allows users to claim their accumulated rewards
    function claimRewards() external nonReentrant {
        uint256 start = lastClaimedToken[msg.sender] + 1;
        uint256 end = currentMint;
        uint256 payout;

        for (uint256 tokenId = start; tokenId <= end;) {
            uint256 w = weightSnapshot[tokenId][msg.sender];
            if (w > 0) {
                payout += (accRewardPerShare[tokenId] * w) / PRECISION;
                delete weightSnapshot[tokenId][msg.sender];
            }
            unchecked {
                tokenId++;
            }
        }

        lastClaimedToken[msg.sender] = end;
        if (payout == 0) revert NoRewardsToClaim();

        (bool success,) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();

        emit CommunityRewardsClaimed(currentMint, msg.sender, payout);
    }

    /// ADMIN ///

    /// @notice Create a new token with custom metadata
    /// @param _metadata The metadata for the token
    /// @dev This function increments currentMint and creates a new token
    function createToken(string memory _metadata) external onlyRole(ADMIN_ROLE) {
        // Distribute previous cycle's rewards using stored totals (no loops)
        uint256 totalRewards = tokenCommunityRewards[currentMint];
        uint256 totalWeight = totalWeightPerCycle[currentMint];
        if (totalRewards > 0) {
            if (totalWeight > 0) {
                accRewardPerShare[currentMint] = (totalRewards * PRECISION) / totalWeight;
                // Calculate dust and roll over
                uint256 distributed = (accRewardPerShare[currentMint] * totalWeight) / PRECISION;
                uint256 dust = totalRewards - distributed;
                if (dust > 0) {
                    tokenCommunityRewards[currentMint + 1] += dust;
                }
            } else {
                // No weight recorded: roll entire pot
                tokenCommunityRewards[currentMint + 1] += totalRewards;
            }
        }

        // Increment to the next token
        ++currentMint;

        // Create the new token
        tokenMetadata[currentMint] = TokenMetadata({metadata: _metadata, createdAt: block.timestamp});

        emit TokenCreated(currentMint, _metadata);
    }

    function setPaused(bool _setPaused) external onlyOwner {
        _setPaused ? _pause() : _unpause();
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    /// @notice Update the burn, artist, and community percentages
    /// @param _burnPercentage New burn percentage (10_000 = 100%)
    /// @param _artistPercentage New artist percentage (10_000 = 100%)
    /// @param _communityPercentage New community percentage (10_000 = 100%)
    function setPercentages(uint256 _burnPercentage, uint256 _artistPercentage, uint256 _communityPercentage)
        external
        onlyOwner
    {
        if (_burnPercentage + _artistPercentage + _communityPercentage > 10_000) {
            revert InvalidPercentage();
        }
        burnPercentage = uint16(_burnPercentage);
        artistPercentage = uint16(_artistPercentage);
        communityPercentage = uint16(_communityPercentage);
        emit PercentagesUpdated(_burnPercentage, _artistPercentage, _communityPercentage);
    }

    /// @notice Allows the owner to update the metadata URI for an existing token
    /// @param _tokenId The token ID to update
    /// @param _newMetadata The new metadata URI
    function updateTokenMetadata(uint256 _tokenId, string memory _newMetadata) external onlyOwner {
        if (!hasMetadata(_tokenId)) revert MetadataNotSet();
        tokenMetadata[_tokenId].metadata = _newMetadata;
        emit MetadataUpdated(_tokenId, _newMetadata);
    }

    /// VIEW ///

    /// @notice This view function returns the art for any given token Id.
    /// @param  _tokenId The token Id of the NFT.
    function uri(uint256 _tokenId) public view override returns (string memory) {
        return tokenMetadata[_tokenId].metadata;
    }

    /// @notice Checks if metadata has been set for a token
    /// @param  _tokenId The token Id to check
    function hasMetadata(uint256 _tokenId) public view returns (bool) {
        return bytes(tokenMetadata[_tokenId].metadata).length > 0;
    }

    /// @dev Helper to return a user's weight for reward distribution
    function weightOf(address user) public view returns (uint256) {
        // Streak weight: 1 + (streak * 0.1), max 2x multiplier
        uint256 streak = mintingStreak[user];
        return 10 + (streak > 10 ? 10 : streak);
    }

    /// @notice Returns the total pending community rewards for a user
    /// @param user The address of the minter
    /// @return The total ETH amount currently claimable by the user
    function unclaimedRewards(address user) external view returns (uint256) {
        uint256 start = lastClaimedToken[user] + 1;
        uint256 end = currentMint;
        uint256 total;
        for (uint256 tokenId = start; tokenId <= end; tokenId++) {
            uint256 w = weightSnapshot[tokenId][user];
            if (w > 0) {
                total += (accRewardPerShare[tokenId] * w) / PRECISION;
            }
        }
        return total;
    }

    /// @notice Returns the original community pot for a given cycle
    /// @param tokenId The cycle/token ID to query
    function communityRewards(uint256 tokenId) external view returns (uint256) {
        return tokenCommunityRewards[tokenId];
    }

    /// @notice Returns the contract-level metadata URI for marketplaces
    function contractURI() external view returns (string memory) {
        return contractMetadataURI;
    }

    /// @notice Sets the contract-level metadata URI (e.g., OpenSea contract metadata)
    function setContractURI(string calldata _uri) external onlyOwner {
        contractMetadataURI = _uri;
    }

    /// @notice Returns the total number of mints for a given token
    /// @param tokenId The token ID to check
    /// @return The total number of mints for the token
    function mintsPerToken(uint256 tokenId) public view returns (uint256) {
        return _totalMintsPerToken[tokenId];
    }
}
