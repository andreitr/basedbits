// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {BBitsBurnerArt} from "@src/modules/BBitsBurnerArt.sol";

/// @title  BBitsBurnerNFT
/// @notice This contract allows users to mint ERC721 NFTs by burning BBITS tokens through Uniswap V3 routing.
contract BBitsBurnerNFT is BBitsBurnerArt, ERC721, ReentrancyGuard {
    /// @notice dEaD address.
    address public constant dead = 0x000000000000000000000000000000000000dEaD;

    /// @notice Wrapped ether.
    IERC20 public constant WETH = IERC20(0x4200000000000000000000000000000000000006);

    /// @notice Based Bits fungible token.
    IERC20 public immutable BBITS;

    /// @notice Uniswap V3 router.
    IV3Router public immutable uniV3Router;

    /// @notice Uniswap V3 BBITS pool.
    IV3Quoter public immutable uniV3Quoter;

    /// @notice Price to mint and NFT, denominated in BBITS burned.
    uint256 public mintPriceInBBITS;

    /// @notice The total supply of NFTs minted.
    uint256 public totalSupply;

    constructor(address _owner, IERC20 _BBITS, IV3Router _router, IV3Quoter _quoter)
        Ownable(_owner)
        ERC721("Based Bits Burner NFT", "BBB")
    {
        BBITS = _BBITS;
        uniV3Router = _router;
        uniV3Quoter = _quoter;
        mintPriceInBBITS = 1024e18;
        WETH.approve(address(uniV3Router), ~uint256(0));
    }

    /// EXTERNAL ///

    receive() external payable {}

    /// @notice Allows users to mint an NFT by paying in WETH, which will be swapped to BBITS and burned.
    /// @dev    Swaps WETH to BBITS via Uniswap V3 and mints an NFT to the sender.
    function mint() external payable nonReentrant {
        /// Ensure WETH is paid
        uint256 priceInWETH = mintPriceInWETH();
        if (msg.value < priceInWETH) revert InsufficientETHPaid();
        /// Deposit to receive WETH
        (bool success,) = address(WETH).call{value: msg.value}("");
        if (!success) revert WETHDepositFailed();
        /// Swap
        IV3Router.ExactOutputSingleParams memory params = IV3Router.ExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(BBITS),
            fee: 3000,
            recipient: dead,
            amountOut: mintPriceInBBITS,
            amountInMaximum: ~uint256(0),
            sqrtPriceLimitX96: 0
        });
        uniV3Router.exactOutputSingle(params);
        /// Mint
        _set(totalSupply);
        _mint(msg.sender, totalSupply++);
    }

    /// @notice Fetches the price of minting an NFT in WETH by querying the Uniswap quoter.
    /// @dev    This function interacts with the Uniswap V3 quoter contract, so it is not a view function.
    /// @return price The cost of minting an NFT, denominated in WETH.
    function mintPriceInWETH() public returns (uint256 price) {
        IV3Quoter.QuoteExactOutputSingleParams memory params = IV3Quoter.QuoteExactOutputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(BBITS),
            amount: mintPriceInBBITS,
            fee: 3000,
            sqrtPriceLimitX96: 0
        });
        (price,,,) = uniV3Quoter.quoteExactOutputSingle(params);
    }

    /// VIEW ///

    /// @notice Retrieves the URI for a given token ID.
    /// @dev    Requires that the token ID is owned by the caller, then generates the URI.
    /// @param  tokenId The ID of the token to retrieve the URI for.
    /// @return The URI string for the token's metadata.
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _draw(tokenId);
    }

    /// OWNER ///

    /// @notice Updates the mint price in BBITS. Can only be called by the contract owner.
    /// @param  _newPrice The new price in BBITS required to mint an NFT.
    function setMintPriceInBBITS(uint256 _newPrice) external onlyOwner {
        mintPriceInBBITS = _newPrice;
    }
}
