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
contract AEYE is
    ERC1155Supply,
    Ownable,
    Pausable,
    AccessControl,
    ReentrancyGuard
{
    /// @notice The price to mint an NFT.
    uint256 public mintPrice;

    /// @notice The token id of the current NFT.
    uint256 public currentMint;

    /// @notice The artist address that receives a portion of mint fees
    address public immutable artist;

    /// @notice The burner contract that handles buy and burns
    Burner public immutable burner;

    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    /// @dev    10_000 = 100%
    uint256 public artistPercentage;

    /// @dev    10_000 = 100%
    uint256 public communityPercentage;

    /// @notice A mapping to track addresses that have minted in a given cycle.
    /// @dev    cycleId => address => minted
    mapping(uint256 => mapping(address => bool)) public hasMinted;

    /// @notice A mapping to track active minters for the current token
    /// @dev    address => isActive
    mapping(address => bool) public activeMinters;

    /// @notice Array of active minters for the current token
    address[] public currentActiveMinters;

    /// @notice A mapping to track user's minting streak
    /// @dev    address => streak
    mapping(address => uint256) public mintingStreak;

    /// @notice A mapping to track total unique minters across all tokens
    /// @dev    address => totalMints
    mapping(address => uint256) public totalMints;

    /// @notice A mapping to track total community rewards distributed
    /// @dev    address => totalRewardsDistributed
    mapping(address => uint256) public totalRewardsDistributed;

    /// @notice A mapping to track community rewards for each token
    /// @dev    tokenId => totalCommunityRewards
    mapping(uint256 => uint256) public tokenCommunityRewards;

    /// @notice A mapping to track user's total accumulated rewards
    /// @dev    address => totalRewards
    mapping(address => uint256) public userRewards;

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
    error WithdrawFailed();
    error InvalidPercentage();
    error TransferFailed();
    error NoRewardsToClaim();

    event Start(uint256 indexed tokenId);
    event TokenCreated(uint256 indexed tokenId, string metadata);
    event MetadataUpdated(uint256 indexed tokenId, string newMetadata);
    event PercentagesUpdated(
        uint256 burnPercentage,
        uint256 artistPercentage,
        uint256 communityPercentage
    );
    event CommunityRewardsClaimed(
        uint256 indexed tokenId,
        address indexed user,
        uint256 amount
    );

    /// @dev Begins paused to allow owner to add art.
    constructor(
        address _owner,
        address _artist,
        address _burner
    ) ERC1155("") Ownable(_owner) {
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Allows the contract to receive ETH payments
    receive() external payable {}

    /// @notice This function provides the core functionality for minting NFTs and transitioning to new cycles.
    function mint() external payable nonReentrant whenNotPaused {
        if (!hasMetadata(currentMint)) revert MetadataNotSet();
        if (msg.value < mintPrice) revert MustPayMintPrice();

        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        uint256 artistAmount = (msg.value * artistPercentage) / 10_000;
        uint256 communityAmount = (msg.value * communityPercentage) / 10_000;
        uint256 ownerAmount = msg.value -
            burnAmount -
            artistAmount -
            communityAmount;

        // Send to burner
        if (burnAmount > 0) {
            burner.burn{value: burnAmount}(0);
        }

        // Send to artist
        if (artistAmount > 0) {
            (bool success, ) = artist.call{value: artistAmount}("");
            if (!success) revert TransferFailed();
        }

        // Add to community rewards
        if (communityAmount > 0) {
            tokenCommunityRewards[currentMint] += communityAmount;
        }

        // Send remaining to owner
        if (ownerAmount > 0) {
            (bool success, ) = owner().call{value: ownerAmount}("");
            if (!success) revert TransferFailed();
        }

        _mintEntry();
    }

    /// @dev Mints the current token to the caller
    function _mintEntry() internal {
        _mint(msg.sender, currentMint, 1, "");
        hasMinted[currentMint][msg.sender] = true;

        // Update streak
        if (currentMint > 0 && hasMinted[currentMint - 1][msg.sender]) {
            mintingStreak[msg.sender]++;
        } else {
            mintingStreak[msg.sender] = 1;
        }

        if (!activeMinters[msg.sender]) {
            activeMinters[msg.sender] = true;
            currentActiveMinters.push(msg.sender);
        }
    }

    /// @notice Allows users to claim their accumulated rewards
    function claimRewards() external nonReentrant {
        uint256 rewards = userRewards[msg.sender];
        if (rewards == 0) revert NoRewardsToClaim();

        // Reset user's rewards
        userRewards[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: rewards}("");
        if (!success) revert TransferFailed();

        emit CommunityRewardsClaimed(currentMint, msg.sender, rewards);
    }

    /// ADMIN ///

    /// @notice Create a new token with custom metadata
    /// @param _metadata The metadata for the token
    /// @dev This function increments currentMint and creates a new token
    function createToken(
        string memory _metadata
    ) external onlyRole(ADMIN_ROLE) {
        // Distribute previous day's rewards to active minters
        uint256 totalRewards = tokenCommunityRewards[currentMint];
        if (totalRewards > 0 && currentActiveMinters.length > 0) {
            // Calculate total weight based on streaks
            uint256 totalWeight = 0;
            for (uint256 i = 0; i < currentActiveMinters.length; i++) {
                address minter = currentActiveMinters[i];
                // Streak weight: 1 + (streak * 0.1), max 2x multiplier
                uint256 weight = 10 +
                    (mintingStreak[minter] > 10 ? 10 : mintingStreak[minter]);
                totalWeight += weight;
            }

            // Distribute rewards based on weights
            for (uint256 i = 0; i < currentActiveMinters.length; i++) {
                address minter = currentActiveMinters[i];
                uint256 weight = 10 +
                    (mintingStreak[minter] > 10 ? 10 : mintingStreak[minter]);
                uint256 share = (totalRewards * weight) / totalWeight;
                userRewards[minter] += share;
                totalRewardsDistributed[minter] += share;
            }
        }

        // Reset active minters for new token
        for (uint256 i = 0; i < currentActiveMinters.length; i++) {
            activeMinters[currentActiveMinters[i]] = false;
        }
        delete currentActiveMinters;

        // Increment to the next token
        ++currentMint;

        // Create the new token
        tokenMetadata[currentMint] = TokenMetadata({
            metadata: _metadata,
            createdAt: block.timestamp
        });

        emit TokenCreated(currentMint, _metadata);
        emit Start(currentMint);
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
    function setPercentages(
        uint256 _burnPercentage,
        uint256 _artistPercentage,
        uint256 _communityPercentage
    ) external onlyOwner {
        if (_burnPercentage + _artistPercentage + _communityPercentage > 10_000)
            revert InvalidPercentage();
        burnPercentage = _burnPercentage;
        artistPercentage = _artistPercentage;
        communityPercentage = _communityPercentage;
        emit PercentagesUpdated(
            _burnPercentage,
            _artistPercentage,
            _communityPercentage
        );
    }

    /// @notice Allows the owner to update the metadata URI for an existing token
    /// @param _tokenId The token ID to update
    /// @param _newMetadata The new metadata URI
    function updateTokenMetadata(
        uint256 _tokenId,
        string memory _newMetadata
    ) external onlyOwner {
        if (!hasMetadata(_tokenId)) revert MetadataNotSet();
        tokenMetadata[_tokenId].metadata = _newMetadata;
        emit MetadataUpdated(_tokenId, _newMetadata);
    }

    /// VIEW ///

    /// @notice This view function returns the art for any given token Id.
    /// @param  _tokenId The token Id of the NFT.
    function uri(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return tokenMetadata[_tokenId].metadata;
    }

    /// @notice Checks if metadata has been set for a token
    /// @param  _tokenId The token Id to check
    function hasMetadata(uint256 _tokenId) public view returns (bool) {
        return bytes(tokenMetadata[_tokenId].metadata).length > 0;
    }

    /// @notice Get the total accumulated rewards for a user
    /// @param _user The address to check rewards for
    /// @return The total amount of accumulated rewards
    function getTotalRewards(address _user) public view returns (uint256) {
        return userRewards[_user];
    }

    /// @notice Get a user's reward percentage for the current token
    /// @param _user The address to check percentage for
    /// @return The user's percentage of rewards (in basis points, 10000 = 100%)
    function getRewardPercentage(address _user) public view returns (uint256) {
        if (!activeMinters[_user] || !hasMinted[currentMint][_user]) return 0;

        uint256 activeMinterCount = 0;
        // Count active minters for current token only
        if (hasMinted[currentMint][_user] && activeMinters[_user]) {
            activeMinterCount++;
        }
        if (activeMinterCount == 0) return 0;

        return 10_000 / activeMinterCount;
    }

    function getTotalRewardsDistributed(
        address _user
    ) public view returns (uint256) {
        return totalRewardsDistributed[_user];
    }
}
