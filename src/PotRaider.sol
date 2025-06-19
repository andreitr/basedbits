// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PotRaider is ERC721, ERC721Burnable, Ownable, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public mintPrice;
    uint256 public burnPercentage;
    address public burnerContract;
    uint256 public totalMinted;

    /// @notice OpenSea-style contract-level metadata URI
    string public contractMetadataURI;

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

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return _generateTokenURI(tokenId);
    }

    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        string memory svg = _generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Pot Raider #',
                        Strings.toString(tokenId),
                        '", "description": "A Pot Raider NFT", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}' 
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _generateSVG(uint256 tokenId) internal pure returns (string memory) {
        (uint8 r, uint8 g, uint8 b) = _generateHueRGB(tokenId);
        
        string memory backgroundColor = string(abi.encodePacked(
            "rgb(",
            Strings.toString(r),
            ",",
            Strings.toString(g),
            ",",
            Strings.toString(b),
            ")"
        ));
        
        return string(abi.encodePacked(
            '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="',
            backgroundColor,
            '"/><path d="M15 32H16V37H17V34H18V37H19V34H20V37H21V34H22V37H23V34H24V37H25V34H26V37H27V34H28V36H29V34H30V30H31V31H32V29H33V32H32V36H31V37H30V38H29V39H28V40H16V39H15V32Z" fill="white"/><path d="M34 29V28H32V29H30V28H28V30H27V31H26V30H25V31H24V30H23V31H22V30H21V31H20V30H19V31H18V30H17V31H16V30H15V31H14V30H13V28H11V27H10V24H11V15H12V13H13V11H14V10H15V9H16V8H18V7H29V8H31V9H33V10H34V11H35V12H36V14H37V16H38V25H37V27H36V28H35V29H34Z" fill="white"/><path d="M21 24V27H20V26H19V27H18V24H19V23H20V24H21Z" fill="#1E1E1E"/><path d="M21 23V19H22V18H23V17H24V16H28V17H29V18H30V19H31V24H30V25H29V26H24V25H23V24H22V23H21Z" fill="black"/><path d="M23 18H24V17H28V18H29V19H30V23H29V24H28V25H24V24H23V23H22V19H23V18Z" fill="#FEC94F"/><path d="M24 18H28V19H24V18Z" fill="#EA9412"/><path d="M24 23H28V24H24V23Z" fill="#EA9412"/><path d="M23 19H24V23H23V19Z" fill="#EA9412"/><path d="M28 19H29V23H28V19Z" fill="#EA9412"/><path d="M25 20H27V22H25V20Z" fill="#EA9412"/><rect x="25" y="20" width="1" height="1" fill="white"/><path d="M8 23V19H9V18H10V17H11V16H15V17H16V18H17V19H18V24H17V25H16V26H11V25H10V24H9V23H8Z" fill="black"/><path d="M10 18H11V17H15V18H16V19H17V23H16V24H15V25H11V24H10V23H9V19H10V18Z" fill="#FEC94F"/><path d="M11 18H15V19H11V18Z" fill="#EA9412"/><path d="M11 23H15V24H11V23Z" fill="#EA9412"/><path d="M10 19H11V23H10V19Z" fill="#EA9412"/><path d="M15 19H16V23H15V19Z" fill="#EA9412"/><path d="M12 20H14V22H12V20Z" fill="#EA9412"/><rect x="12" y="20" width="1" height="1" fill="white"/><path d="M13 11H14V13H13V11Z" fill="#E9E9E9"/><path d="M12 13H13V14H15V15H12V13Z" fill="#E9E9E9"/><path d="M15 15H16V16H15V15Z" fill="#E9E9E9"/><path d="M11 15H12V16H11V15Z" fill="#E9E9E9"/><path d="M23 14H24V15H23V14Z" fill="#E9E9E9"/><path d="M24 13H28V14H24V13Z" fill="#E9E9E9"/><path d="M21 23H22V24H21V23Z" fill="#E9E9E9"/><path d="M20 18H21V16H22V15H23V16H24V17H23V18H22V19H21V23H20V18Z" fill="#E9E9E9"/><path d="M17 24H18V25H17V24Z" fill="#E9E9E9"/><path d="M22 24H23V25H22V24Z" fill="#E9E9E9"/><path d="M16 28H17V29H16V28Z" fill="#E9E9E9"/><path d="M20 28H21V29H20V28Z" fill="#E9E9E9"/><path d="M18 28H19V29H18V28Z" fill="#E9E9E9"/><path d="M22 28H23V29H22V28Z" fill="#E9E9E9"/><path d="M29 25H30V26H29V25Z" fill="#E9E9E9"/><path d="M30 24H31V25H30V24Z" fill="#E9E9E9"/><path d="M19 18V24H18V19H17V18H19Z" fill="#E9E9E9"/><path d="M16 16H17V17H16V16Z" fill="#E9E9E9"/><path d="M14 10H15V11H14V10Z" fill="#E9E9E9"/><path d="M15 9H16V10H15V9Z" fill="#E9E9E9"/><path d="M16 8H18V9H16V8Z" fill="#E9E9E9"/><path d="M29 7H18V8H27V9H28V10H29V11H30V12H31V14H28V17H29V18H30V19H32V24H34V25H33V26H32V27H29V26H24V25H23V27H24V29H26V31H27V30H28V28H30V29H32V28H34V29H35V28H36V27H37V25H38V16H37V14H36V12H35V11H34V10H33V9H31V8H29V7Z" fill="#E9E9E9"/><path d="M17 25H16V26H12V27H11V28H13V30H14V31H15V30H16V29H15V28H16V27H17V25Z" fill="#E9E9E9"/><path d="M33 32V29H32V31H31V30H30V34H29V36H28V34H27V37H26V34H25V37H24V34H23V37H22V34H21V37H20V34H19V37H18V34H17V37H16V32H15V38H21V39H25V40H28V39H29V38H30V37H31V36H32V32H33Z" fill="#E9E9E9"/><path d="M26 7H29V8H26V7Z" fill="#B9B9B9"/><path d="M29 8H31V9H29V8Z" fill="#B9B9B9"/><path d="M31 9H33V10H31V9Z" fill="#B9B9B9"/><path d="M33 10H34V11H33V10Z" fill="#B9B9B9"/><path d="M34 11H35V12H34V11Z" fill="#B9B9B9"/><path d="M11 15H12V16H11V15Z" fill="#B9B9B9"/><path d="M12 13H13V15H12V13Z" fill="#B9B9B9"/><path d="M24 26H29V27H28V28H25V27H24V26Z" fill="#B9B9B9"/><path d="M29 25H30V26H29V25Z" fill="#B9B9B9"/><path d="M30 28H32V29H30V28Z" fill="#B9B9B9"/><path d="M30 30H31V31H32V36H31V32H30V30Z" fill="#B9B9B9"/><path d="M30 24H31V25H30V24Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#B9B9B9"/><path d="M29 17H30V18H29V17Z" fill="#B9B9B9"/><path d="M28 16H29V17H28V16Z" fill="#B9B9B9"/><path d="M28 14H29V15H28V14Z" fill="#B9B9B9"/><path d="M29 15H30V16H29V15Z" fill="#B9B9B9"/><path d="M30 16H31V17H30V16Z" fill="#B9B9B9"/><path d="M20 19H21V22H20V19Z" fill="#B9B9B9"/><path d="M18 19H19V22H18V19Z" fill="#B9B9B9"/><path d="M17 18H18V19H17V18Z" fill="#B9B9B9"/><path d="M16 17H17V18H16V17Z" fill="#B9B9B9"/><path d="M15 16H16V17H15V16Z" fill="#B9B9B9"/><path d="M21 17H22V16H24V17H23V18H22V19H21V17Z" fill="#B9B9B9"/><path d="M26 30H27V31H26V30Z" fill="#B9B9B9"/><path d="M17 35H18V37H19V35H20V37H21V35H22V37H23V35H24V37H25V35H26V37H27V35H28V36H29V34H30V36H31V37H30V38H29V39H28V38H17V35Z" fill="#B9B9B9"/><path d="M15 32H16V35H15V32Z" fill="#B9B9B9"/><path d="M26 39H28V40H26V39Z" fill="#B9B9B9"/><path d="M12 26H16V27H15V28H14V30H13V28H11V27H12V26Z" fill="#B9B9B9"/><path d="M35 12H36V14H35V12Z" fill="#B9B9B9"/><path d="M36 14H37V16H36V14Z" fill="#B9B9B9"/><path d="M37 16H38V25H37V27H36V28H35V29H34V28H32V26H33V25H34V24H33V23H32V20H33V19H35V17H36V18H37V16Z" fill="#B9B9B9"/><path d="M23 25H24V26H23V25Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#919191"/><path d="M30 16H31V17H30V16Z" fill="#919191"/><path d="M29 15H30V16H29V15Z" fill="#919191"/><path d="M28 16H29V17H28V16Z" fill="#919191"/><path d="M29 17H30V18H29V17Z" fill="#919191"/><path d="M22 17H23V18H22V17Z" fill="#919191"/><path d="M16 17H17V18H16V17Z" fill="#919191"/><path d="M13 26H15V27H14V28H13V26Z" fill="#919191"/><path d="M17 28H18V30H17V28Z" fill="#919191"/><path d="M15 28H16V30H15V28Z" fill="#919191"/><path d="M19 28H20V30H19V28Z" fill="#919191"/><path d="M21 28H22V30H21V28Z" fill="#919191"/><path d="M23 28H24V30H23V28Z" fill="#919191"/><path d="M25 26H28V27H29V28H28V30H27V27H25V26Z" fill="#919191"/><path d="M25 28H26V30H25V28Z" fill="#919191"/><path d="M23 16H24V17H23V16Z" fill="#919191"/><path d="M32 24V21H33V22H36V24H32Z" fill="#919191"/><path d="M33 25H36V24H37V16H38V25H37V27H36V28H35V29H34V27H32V26H33V25Z" fill="#919191"/><path d="M30 35H31V31H32V29H33V32H32V36H31V37H30V35Z" fill="#919191"/><path d="M29 34H30V35H29V34Z" fill="#919191"/><path d="M27 36H28V37H27V36Z" fill="#919191"/><path d="M21 36H22V37H21V36Z" fill="#919191"/><path d="M19 36H20V37H19V36Z" fill="#919191"/><path d="M17 36H18V37H17V36Z" fill="#919191"/><path d="M25 36H26V37H25V36Z" fill="#919191"/><path d="M23 36H24V37H23V36Z" fill="#919191"/><path d="M29 37H30V38H29V37Z" fill="#919191"/><path d="M28 38H29V39H28V38Z" fill="#919191"/><path d="M27 39H28V40H27V39Z" fill="#919191"/><path d="M36 14H37V16H36V14Z" fill="#919191"/><path d="M35 12H36V14H35V12Z" fill="#919191"/><path d="M34 11H35V12H34V11Z" fill="#919191"/><path d="M33 10H34V11H33V10Z" fill="#919191"/><path d="M30 8H31V9H30V8Z" fill="#919191"/><path d="M28 7H29V8H28V7Z" fill="#919191"/><path d="M32 9H33V10H32V9Z" fill="#919191"/><path d="M33 23H35V24H33V23Z" fill="#656565"/><path d="M36 25H37V27H36V25Z" fill="#656565"/><path d="M32 29H33V32H32V29Z" fill="#656565"/><path d="M37 23H38V25H37V23Z" fill="#656565"/><path d="M31 35H32V36H31V35Z" fill="#656565"/></svg>'
        ));
    }

    function _generateHueRGB(uint256 seed) private pure returns (uint8 r, uint8 g, uint8 b) {
        uint256 hue = seed % 360;
        uint256 c = 128;
        uint256 m = 64;
        
        // Calculate which sextant of the color wheel we're in
        uint256 sextant = hue / 60;
        uint256 remainder = hue % 60;
        
        // Calculate the intermediate value
        uint256 x = (c * (60 - remainder)) / 60;
        
        if (sextant == 0) {
            return (uint8(c + m), uint8(x + m), uint8(m));
        } else if (sextant == 1) {
            return (uint8(x + m), uint8(c + m), uint8(m));
        } else if (sextant == 2) {
            return (uint8(m), uint8(c + m), uint8(x + m));
        } else if (sextant == 3) {
            return (uint8(m), uint8(x + m), uint8(c + m));
        } else if (sextant == 4) {
            return (uint8(x + m), uint8(m), uint8(c + m));
        } else {
            return (uint8(c + m), uint8(m), uint8(x + m));
        }
    }

    /// @notice Returns the contract-level metadata URI for marketplaces
    function contractURI() external view returns (string memory) {
        return contractMetadataURI;
    }

    /// @notice Sets the contract-level metadata URI (e.g., OpenSea contract metadata)
    function setContractURI(string calldata _uri) external onlyOwner {
        contractMetadataURI = _uri;
    }
}
