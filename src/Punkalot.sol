// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {PunksALotArt} from "@src/modules/PunksALotArt.sol";
import {IBBitsCheckIn} from "@src/interfaces/IBBitsCheckIn.sol";

/// @title  PunksALot
/// @dev    - Max supply of 1000.
///         - Original onchain art.
///         - Up to thee mint discounts based on Based Bits Check In streak.
///         - Mint funds distributed between the artist, Greta Gremplin, and the BBITS token through a buyback and burn.
contract Punkalot is ERC721, ReentrancyGuard, Ownable, PunksALotArt {
    /// @notice The BBITS burner contract that automates buy and burns
    Burner public immutable burner;

    /// @notice Based Bits checkin contract.
    IBBitsCheckIn public immutable checkIn;

    /// @notice Greta Gremplin
    address public immutable artist;

    uint256 public immutable supplyCap;

    uint256 public totalSupply;

    uint256 public mintFee;

    /// @dev    10_000 = 100%
    uint256 public burnPercentage;

    /// @dev A mapping to track how many discounted NFTS have been minted
    ///      User => Number
    mapping(address => uint256) numberDiscounted;

    constructor(address _owner, address _artist, address _burner, address _checkIn)
        ERC721("Punkalot", "PUNKS")
        Ownable(_owner)
    {
        artist = _artist;
        burner = Burner(_burner);
        checkIn = IBBitsCheckIn(_checkIn);
        burnPercentage = 5000;
        supplyCap = 1000;
        mintFee = 0.0015 ether;
    }

    receive() external payable {}

    /// @notice Mint a new NFT, paying a dynamic fee that may include a discount based on BBITS streaks.
    /// @dev    Raise gas limit on transactions to prevent a revert; the pseudo-random generator fools the wallets.
    function mint() external payable nonReentrant {
        if (totalSupply >= supplyCap) revert CapExceeded();
        uint256 mintPrice = userMintPrice(msg.sender);
        if (msg.value < mintPrice) revert InsufficientETHPaid();
        if (mintPrice < mintFee) numberDiscounted[msg.sender]++;
        uint256 burnAmount = (mintPrice * burnPercentage) / 10_000;
        burner.burn{value: burnAmount}(0);
        (bool success,) = artist.call{value: mintPrice - burnAmount}("");
        if (!success) revert TransferFailed();
        _set(totalSupply);
        _mint(msg.sender, totalSupply++);
    }

    /// @notice This view function returns the current price to mint an NFT for any given user. Users can
    ///         decrease their mint price by up to 90% by gaining a streak in the associated BBits CheckIn
    ///         contract: 0xE842537260634175891925F058498F9099C102eB. This discount only applies to the
    ///         first three mints however.
    /// @param  _user The user paying to mint a new NFT.
    function userMintPrice(address _user) public view returns (uint256) {
        (uint256 lastCheckIn, uint16 streak,) = checkIn.checkIns(_user);
        if ((numberDiscounted[_user] < 3) && ((block.timestamp - lastCheckIn) < 48 hours)) {
            if (streak > 90) streak = 90;
            return mintFee - ((mintFee * streak) / 100);
        } else {
            return mintFee;
        }
    }

    function setBurnPercentage(uint256 _newBurnPercentage) external onlyOwner {
        if (_newBurnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _newBurnPercentage;
    }

    /// @notice Retrieves the URI for a given token ID.
    /// @dev    Requires that the token ID is owned, then generates the URI.
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
