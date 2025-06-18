// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PotRaider is ERC721, ERC721Burnable, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public mintPrice;
    uint256 public burnPercentage;
    address public burnerContract;
    uint256 public totalMinted;

    event NFTExchanged(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount
    );

    constructor(
        string memory name,
        string memory symbol,
        uint256 _mintPrice,
        uint256 _burnPercentage,
        address _burnerContract
    ) ERC721(name, symbol) Ownable(msg.sender) {
        require(_burnPercentage <= 100, "Burn percentage cannot exceed 100");
        mintPrice = _mintPrice;
        burnPercentage = _burnPercentage;
        burnerContract = _burnerContract;
    }

    function mint(uint256 quantity) external payable whenNotPaused {
        require(quantity > 0, "Quantity must be greater than 0");
        require(quantity <= 10, "Cannot mint more than 10 NFTs at once");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        uint256 burnAmount = (msg.value * burnPercentage) / 100;
        uint256 treasuryAmount = msg.value - burnAmount;

        // Send burn amount to burner contract
        (bool burnSuccess, ) = burnerContract.call{value: burnAmount}("");
        require(burnSuccess, "Burn transfer failed");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _safeMint(msg.sender, newTokenId);
            totalMinted++;
        }
    }

    function exchange(uint256 tokenId) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(totalMinted > 0, "No NFTs minted");

        // Calculate share based on total minted NFTs
        uint256 amount = address(this).balance / totalMinted;
        require(amount > 0, "No treasury available");

        // Burn the NFT
        burn(tokenId);

        // Send share to the owner
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit NFTExchanged(tokenId, msg.sender, amount);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
        require(_burnPercentage <= 100, "Burn percentage cannot exceed 100");
        burnPercentage = _burnPercentage;
    }

    function setBurnerContract(address _burnerContract) external onlyOwner {
        burnerContract = _burnerContract;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Burnable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}
