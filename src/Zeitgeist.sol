// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1155} from "@openzeppelin/token/ERC1155/ERC1155.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {ERC1155Supply} from "@src/modules/ERC1155Supply.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/utils/introspection/IERC165.sol";

/// @title  Zeitgeist
/// @notice This contract allows users to mint daily NFTs with unique artwork.
/// @dev    The contract operates on admin-initiated cycles, where admins can create new tokens with custom SVG and metadata.
///         The Owner retains admin rights over pausability and the mintPrice.
contract Zeitgeist is
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

    /// @notice A mapping to track addresses that have minted in a given cycle.
    /// @dev    cycleId => address => minted
    mapping(uint256 => mapping(address => bool)) public hasMinted;

    /// @notice A mapping to store token metadata
    /// @dev    tokenId => metadata
    mapping(uint256 => TokenMetadata) public tokenMetadata;

    /// @notice Role identifier for admin
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct TokenMetadata {
        string svg;
        string metadata;
        uint256 createdAt;
    }

    error MustPayMintPrice();
    error MetadataNotSet();
    error WithdrawFailed();

    event Start(uint256 indexed tokenId);
    event End(uint256 indexed tokenId);
    event TokenCreated(uint256 indexed tokenId, string svg, string metadata);
    event Withdrawn(address indexed to, uint256 amount);

    /// @dev Begins paused to allow owner to add art.
    constructor(address _owner) ERC1155("") Ownable(_owner) {
        mintPrice = 0.0008 ether;

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(ADMIN_ROLE, _owner);

        _pause();
    }

    /// @notice Override supportsInterface to resolve conflicts between ERC1155 and AccessControl
    /// @param interfaceId The interface identifier to check
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
        _mintEntry();
    }

    /// ADMIN ///

    /// @notice Create a new token with custom SVG and metadata
    /// @param _svg The SVG content for the token
    /// @param _metadata The metadata for the token
    /// @dev This function increments currentMint and creates a new token
    function createToken(
        string memory _svg,
        string memory _metadata
    ) external onlyRole(ADMIN_ROLE) {
        // End the current mint cycle if not the first token
        if (currentMint > 0) {
            emit End(currentMint);
        }

        // Increment to the next token
        ++currentMint;

        // Create the new token
        tokenMetadata[currentMint] = TokenMetadata({
            svg: _svg,
            metadata: _metadata,
            createdAt: block.timestamp
        });

        emit TokenCreated(currentMint, _svg, _metadata);
        emit Start(currentMint);
    }

    /// @notice Manually ends the current mint cycle without starting a new one
    /// @dev Use this if you want to stop minting without creating a new token
    function endCurrentMint() external onlyRole(ADMIN_ROLE) {
        emit End(currentMint);
    }

    /// @notice Allows the owner to withdraw accumulated ETH
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawFailed();
        emit Withdrawn(msg.sender, amount);
    }

    function setPaused(bool _setPaused) external onlyOwner {
        _setPaused ? _pause() : _unpause();
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
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

    /// INTERNAL ///

    /// @dev Mints the current token to the caller
    function _mintEntry() internal {
        _mint(msg.sender, currentMint, 1, "");
        hasMinted[currentMint][msg.sender] = true;
    }
}
