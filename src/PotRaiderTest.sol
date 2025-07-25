// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/Pausable.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

// Uniswap V3 Router interface for ETH→USDC swaps
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

// Lottery contract interface
interface ILotteryContract {
    function purchaseTickets(address referrer, uint256 value, address recipient) external;
    function withdrawWinnings() external;
    function lpPoolTotal() external view returns (uint256);
    function lastJackpotEndTime() external view returns (uint256);
    function roundDurationInSeconds() external view returns (uint256);
}

contract PotRaiderTest is ERC721, ERC721Burnable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public totalSupply;
    uint256 public circulatingSupply;
    uint256 public mintPrice;
    uint256 public burnPercentage;
    address public burnerContract;

    // Next tokenId to mint
    uint256 private nextTokenId;

    /// @notice WETH address for Uniswap V3 swaps
    address public wethAddress;

    /// @notice The artist address that receives a portion of mint fees
    address public immutable artist;

    /// @dev    10_000 = 100%
    uint16 public artistPercentage;

    /// @notice OpenSea-style contract-level metadata URI
    string public contractMetadataURI;

    /// @notice Timestamp when the contract was deployed
    uint256 public immutable deploymentTimestamp;

    /// @notice Lottery ticket purchase system variables
    uint256 public lotteryParticipationDays = 365;
    uint256 public constant LOTTERY_TICKET_PRICE_USD = 1; // $1 per ticket
    uint256 public constant USDC_DECIMALS = 6; // USDC has 6 decimals
    uint256 public constant MAX_MINT_PER_CALL = 50; // Max NFTs mintable per call
    address public lotteryContract;
    address public usdcContract;
    address public uniswapRouter; // Uniswap V3 Router for ETH→USDC swaps
    address public uniswapQuoter; // Uniswap V3 Quoter for ETH→USDC estimation
    mapping(uint256 => uint256) public lotteryPurchasedForDay;
    address public lotteryReferrer; // Referrer address for lottery ticket purchases

    event NFTExchanged(uint256 indexed tokenId, address indexed owner, uint256 ethAmount, uint256 usdcAmount);

    event PercentagesUpdated(uint256 burnPercentage, uint256 artistPercentage);

    event LotteryTicketPurchased(uint256 indexed day, uint256 amount);

    event LotteryContractUpdated(address indexed newContract);
    event USDCContractUpdated(address indexed newContract);
    event UniswapQuoterUpdated(address indexed newQuoter);
    event LotteryReferrerUpdated(address indexed newReferrer);

    error InvalidPercentage();
    error TransferFailed();
    error LotteryNotConfigured();
    error LotteryAlreadyPurchased();
    error LotteryPeriodEnded();
    error InsufficientTreasury();
    error USDCNotConfigured();
    error InsufficientUSDCBalance();
    error InsufficientUSDCForTicket();
    error UniswapQuoterNotConfigured();
    error UniswapRouterNotConfigured();
    error QuoterCallFailed();
    error QuantityZero();
    error InsufficientPayment();
    error BurnTransferFailed();
    error ArtistTransferFailed();
    error NotOwner();
    error NoNFTsInCirculation();
    error NoTreasuryAvailable();
    error ExchangeTransferFailed();
    error WETHNotConfigured();
    error MaxMintPerCallExceeded();

    function _checkWETHConfigured() private view {
        if (wethAddress == address(0)) {
            revert WETHNotConfigured();
        }
    }

    constructor(uint256 _mintPrice, address _burnerContract, address _artist)
        ERC721("Pot Raider Test", "POTRAIDERTEST")
        Ownable(msg.sender)
    {
        mintPrice = _mintPrice;
        burnerContract = _burnerContract;
        artist = _artist;
        artistPercentage = 1000; // 10%
        burnPercentage = 1000; // 10%
        deploymentTimestamp = block.timestamp;
    }

    /// @notice Allow contract to receive plain ETH transfers
    receive() external payable {}

    function mint(uint256 quantity) external payable whenNotPaused nonReentrant {
        if (quantity == 0) {
            revert QuantityZero();
        }
        if (quantity > MAX_MINT_PER_CALL) {
            revert MaxMintPerCallExceeded();
        }
        if (msg.value < mintPrice * quantity) {
            revert InsufficientPayment();
        }

        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;
        uint256 artistAmount = (msg.value * artistPercentage) / 10_000;

        // Send burn amount to burner contract
        if (burnAmount > 0) {
            (bool burnSuccess,) = burnerContract.call{value: burnAmount}("");
            if (!burnSuccess) {
                revert BurnTransferFailed();
            }
        }

        // Send artist amount to artist
        if (artistAmount > 0) {
            (bool artistSuccess,) = artist.call{value: artistAmount}("");
            if (!artistSuccess) {
                revert ArtistTransferFailed();
            }
        }

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, nextTokenId);
            nextTokenId++;
            totalSupply++;
            circulatingSupply++;
        }
    }

    function exchange(uint256 tokenId) external whenNotPaused nonReentrant {
        if (ownerOf(tokenId) != msg.sender) {
            revert NotOwner();
        }
        if (circulatingSupply == 0) {
            revert NoNFTsInCirculation();
        }

        // Check ETH balance before proceeding
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) {
            revert NoTreasuryAvailable();
        }
        uint256 ethShare = contractBalance / circulatingSupply;
        if (ethShare == 0) {
            revert NoTreasuryAvailable();
        }

        // Calculate USDC share (if usdcContract is set)
        uint256 usdcShare = 0;
        uint256 usdcBalance = 0;
        if (usdcContract != address(0)) {
            usdcBalance = IERC20(usdcContract).balanceOf(address(this));
            if (usdcBalance == 0) {
                usdcShare = 0;
            } else {
                usdcShare = usdcBalance / circulatingSupply;
            }
        }

        // Burn the NFT first (state update before external calls)
        burn(tokenId);

        // Send USDC share to the owner (if any), but only if balance is sufficient
        if (usdcShare > 0) {
            IERC20(usdcContract).safeTransfer(msg.sender, usdcShare);
        }

        // Send ETH share to the owner
        (bool success,) = msg.sender.call{value: ethShare}("");
        if (!success) {
            revert ExchangeTransferFailed();
        }

        emit NFTExchanged(tokenId, msg.sender, ethShare, usdcShare);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setBurnPercentage(uint256 _burnPercentage) external onlyOwner {
        require(_burnPercentage <= 10_000, "Burn percentage cannot exceed 100%");
        burnPercentage = _burnPercentage;
    }

    /// @notice Update the burn and artist percentages
    /// @param _burnPercentage New burn percentage (10_000 = 100%)
    /// @param _artistPercentage New artist percentage (10_000 = 100%)
    function setPercentages(uint256 _burnPercentage, uint256 _artistPercentage) external onlyOwner {
        require(_burnPercentage <= 10_000, "Burn percentage cannot exceed 100%");
        require(_artistPercentage <= 10_000, "Artist percentage cannot exceed 100%");
        require(_burnPercentage + _artistPercentage <= 10_000, "Total percentages cannot exceed 100%");

        burnPercentage = uint16(_burnPercentage);
        artistPercentage = uint16(_artistPercentage);

        emit PercentagesUpdated(_burnPercentage, _artistPercentage);
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

    /// @notice Deposit ERC20 tokens into the contract treasury
    /// @param token The token to deposit
    /// @param amount The amount of tokens to deposit
    function depositERC20(address token, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) {
            revert QuantityZero();
        }
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Emergency withdraw of ETH or ERC20 tokens
    /// @param token Address of the token to withdraw, or address(0) for ETH
    function emergencyWithdraw(address token) external onlyOwner nonReentrant {
        if (token == address(0)) {
            uint256 bal = address(this).balance;
            (bool success,) = owner().call{value: bal}("");
            if (!success) {
                revert TransferFailed();
            }
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(owner(), bal);
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return _generateTokenURI(tokenId);
    }

    function _generateTokenURI(uint256 tokenId) internal view returns (string memory) {
        string memory svg = _generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Raider #',
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

        string memory backgroundColor = string(
            abi.encodePacked("rgb(", Strings.toString(r), ",", Strings.toString(g), ",", Strings.toString(b), ")")
        );

        // Test NFT
        return string(
            abi.encodePacked(
                '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="#EA9412"/><path d="M33 32H32V36H31V37H30V38H29V39H28V40H16V39H15V32H16V37H17V34H18V37H19V34H20V37H21V34H22V37H23V34H24V37H25V34H26V37H27V34H28V36H29V34H30V30H31V31H32V29H33V32Z" fill="white"/><path fill-rule="evenodd" clip-rule="evenodd" d="M29 8H31V9H33V10H34V11H35V12H36V14H37V16H38V25H37V27H36V28H35V29H34V28H32V29H30V28H28V30H27V31H26V30H25V31H24V30H23V31H22V30H21V31H20V30H19V31H18V30H17V31H16V30H15V31H14V30H13V28H11V27H10V24H11V15H12V13H13V11H14V10H15V9H16V8H18V7H29V8ZM19 23V24H18V27H19V26H20V27H21V24H20V23H19Z" fill="white"/><path d="M23 18H24V17H28V18H29V19H30V23H29V24H28V25H24V24H23V23H22V19H23V18Z" fill="#EA9412"/><rect x="25" y="20" width="1" height="1" fill="white"/><path d="M10 18H11V17H15V18H16V19H17V23H16V24H15V25H11V24H10V23H9V19H10V18Z" fill="#EA9412"/><rect x="12" y="20" width="1" height="1" fill="white"/></svg>'
            )
        );

        // Production NFT
        // return string(abi.encodePacked(
        //     '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="',
        //     backgroundColor,'"/><rect width="48" height="48" fill="black" opacity="0.8"/><path d="M15 32H16V37H17V34H18V37H19V34H20V37H21V34H22V37H23V34H24V37H25V34H26V37H27V34H28V36H29V34H30V30H31V31H32V29H33V32H32V36H31V37H30V38H29V39H28V40H16V39H15V32Z" fill="white"/><path d="M34 29V28H32V29H30V28H28V30H27V31H26V30H25V31H24V30H23V31H22V30H21V31H20V30H19V31H18V30H17V31H16V30H15V31H14V30H13V28H11V27H10V24H11V15H12V13H13V11H14V10H15V9H16V8H18V7H29V8H31V9H33V10H34V11H35V12H36V14H37V16H38V25H37V27H36V28H35V29H34Z" fill="white"/><path d="M21 24V27H20V26H19V27H18V24H19V23H20V24H21Z" fill="#1E1E1E"/><path d="M21 23V19H22V18H23V17H24V16H28V17H29V18H30V19H31V24H30V25H29V26H24V25H23V24H22V23H21Z" fill="black"/><path d="M23 18H24V17H28V18H29V19H30V23H29V24H28V25H24V24H23V23H22V19H23V18Z" fill="#FEC94F"/><path d="M24 18H28V19H24V18Z" fill="#EA9412"/><path d="M24 23H28V24H24V23Z" fill="#EA9412"/><path d="M23 19H24V23H23V19Z" fill="#EA9412"/><path d="M28 19H29V23H28V19Z" fill="#EA9412"/><path d="M25 20H27V22H25V20Z" fill="#EA9412"/><rect x="25" y="20" width="1" height="1" fill="white"/><path d="M8 23V19H9V18H10V17H11V16H15V17H16V18H17V19H18V24H17V25H16V26H11V25H10V24H9V23H8Z" fill="black"/><path d="M10 18H11V17H15V18H16V19H17V23H16V24H15V25H11V24H10V23H9V19H10V18Z" fill="#FEC94F"/><path d="M11 18H15V19H11V18Z" fill="#EA9412"/><path d="M11 23H15V24H11V23Z" fill="#EA9412"/><path d="M10 19H11V23H10V19Z" fill="#EA9412"/><path d="M15 19H16V23H15V19Z" fill="#EA9412"/><path d="M12 20H14V22H12V20Z" fill="#EA9412"/><rect x="12" y="20" width="1" height="1" fill="white"/><path d="M13 11H14V13H13V11Z" fill="#E9E9E9"/><path d="M12 13H13V14H15V15H12V13Z" fill="#E9E9E9"/><path d="M15 15H16V16H15V15Z" fill="#E9E9E9"/><path d="M11 15H12V16H11V15Z" fill="#E9E9E9"/><path d="M23 14H24V15H23V14Z" fill="#E9E9E9"/><path d="M24 13H28V14H24V13Z" fill="#E9E9E9"/><path d="M21 23H22V24H21V23Z" fill="#E9E9E9"/><path d="M20 18H21V16H22V15H23V16H24V17H23V18H22V19H21V23H20V18Z" fill="#E9E9E9"/><path d="M17 24H18V25H17V24Z" fill="#E9E9E9"/><path d="M22 24H23V25H22V24Z" fill="#E9E9E9"/><path d="M16 28H17V29H16V28Z" fill="#E9E9E9"/><path d="M20 28H21V29H20V28Z" fill="#E9E9E9"/><path d="M18 28H19V29H18V28Z" fill="#E9E9E9"/><path d="M22 28H23V29H22V28Z" fill="#E9E9E9"/><path d="M29 25H30V26H29V25Z" fill="#E9E9E9"/><path d="M30 24H31V25H30V24Z" fill="#E9E9E9"/><path d="M19 18V24H18V19H17V18H19Z" fill="#E9E9E9"/><path d="M16 16H17V17H16V16Z" fill="#E9E9E9"/><path d="M14 10H15V11H14V10Z" fill="#E9E9E9"/><path d="M15 9H16V10H15V9Z" fill="#E9E9E9"/><path d="M16 8H18V9H16V8Z" fill="#E9E9E9"/><path d="M29 7H18V8H27V9H28V10H29V11H30V12H31V14H28V17H29V18H30V19H32V24H34V25H33V26H32V27H29V26H24V25H23V27H24V29H26V31H27V30H28V28H30V29H32V28H34V29H35V28H36V27H37V25H38V16H37V14H36V12H35V11H34V10H33V9H31V8H29V7Z" fill="#E9E9E9"/><path d="M17 25H16V26H12V27H11V28H13V30H14V31H15V30H16V29H15V28H16V27H17V25Z" fill="#E9E9E9"/><path d="M33 32V29H32V31H31V30H30V34H29V36H28V34H27V37H26V34H25V37H24V34H23V37H22V34H21V37H20V34H19V37H18V34H17V37H16V32H15V38H21V39H25V40H28V39H29V38H30V37H31V36H32V32H33Z" fill="#E9E9E9"/><path d="M26 7H29V8H26V7Z" fill="#B9B9B9"/><path d="M29 8H31V9H29V8Z" fill="#B9B9B9"/><path d="M31 9H33V10H31V9Z" fill="#B9B9B9"/><path d="M33 10H34V11H33V10Z" fill="#B9B9B9"/><path d="M34 11H35V12H34V11Z" fill="#B9B9B9"/><path d="M11 15H12V16H11V15Z" fill="#B9B9B9"/><path d="M12 13H13V15H12V13Z" fill="#B9B9B9"/><path d="M24 26H29V27H28V28H25V27H24V26Z" fill="#B9B9B9"/><path d="M29 25H30V26H29V25Z" fill="#B9B9B9"/><path d="M30 28H32V29H30V28Z" fill="#B9B9B9"/><path d="M30 30H31V31H32V36H31V32H30V30Z" fill="#B9B9B9"/><path d="M30 24H31V25H30V24Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#B9B9B9"/><path d="M29 17H30V18H29V17Z" fill="#B9B9B9"/><path d="M28 16H29V17H28V16Z" fill="#B9B9B9"/><path d="M28 14H29V15H28V14Z" fill="#B9B9B9"/><path d="M29 15H30V16H29V15Z" fill="#B9B9B9"/><path d="M30 16H31V17H30V16Z" fill="#B9B9B9"/><path d="M20 19H21V22H20V19Z" fill="#B9B9B9"/><path d="M18 19H19V22H18V19Z" fill="#B9B9B9"/><path d="M17 18H18V19H17V18Z" fill="#B9B9B9"/><path d="M16 17H17V18H16V17Z" fill="#B9B9B9"/><path d="M15 16H16V17H15V16Z" fill="#B9B9B9"/><path d="M21 17H22V16H24V17H23V18H22V19H21V17Z" fill="#B9B9B9"/><path d="M26 30H27V31H26V30Z" fill="#B9B9B9"/><path d="M17 35H18V37H19V35H20V37H21V35H22V37H23V35H24V37H25V35H26V37H27V35H28V36H29V34H30V36H31V37H30V38H29V39H28V38H17V35Z" fill="#B9B9B9"/><path d="M15 32H16V35H15V32Z" fill="#B9B9B9"/><path d="M26 39H28V40H26V39Z" fill="#B9B9B9"/><path d="M12 26H16V27H15V28H14V30H13V28H11V27H12V26Z" fill="#B9B9B9"/><path d="M35 12H36V14H35V12Z" fill="#B9B9B9"/><path d="M36 14H37V16H36V14Z" fill="#B9B9B9"/><path d="M37 16H38V25H37V27H36V28H35V29H34V28H32V26H33V25H34V24H33V23H32V20H33V19H35V17H36V18H37V16Z" fill="#B9B9B9"/><path d="M23 25H24V26H23V25Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#919191"/><path d="M30 16H31V17H30V16Z" fill="#919191"/><path d="M29 15H30V16H29V15Z" fill="#919191"/><path d="M28 16H29V17H28V16Z" fill="#919191"/><path d="M29 17H30V18H29V17Z" fill="#919191"/><path d="M22 17H23V18H22V17Z" fill="#919191"/><path d="M16 17H17V18H16V17Z" fill="#919191"/><path d="M13 26H15V27H14V28H13V26Z" fill="#919191"/><path d="M17 28H18V30H17V28Z" fill="#919191"/><path d="M15 28H16V30H15V28Z" fill="#919191"/><path d="M19 28H20V30H19V28Z" fill="#919191"/><path d="M21 28H22V30H21V28Z" fill="#919191"/><path d="M23 28H24V30H23V28Z" fill="#919191"/><path d="M25 26H28V27H29V28H28V30H27V27H25V26Z" fill="#919191"/><path d="M25 28H26V30H25V28Z" fill="#919191"/><path d="M23 16H24V17H23V16Z" fill="#919191"/><path d="M32 24V21H33V22H36V24H32Z" fill="#919191"/><path d="M33 25H36V24H37V16H38V25H37V27H36V28H35V29H34V27H32V26H33V25Z" fill="#919191"/><path d="M30 35H31V31H32V29H33V32H32V36H31V37H30V35Z" fill="#919191"/><path d="M29 34H30V35H29V34Z" fill="#919191"/><path d="M27 36H28V37H27V36Z" fill="#919191"/><path d="M21 36H22V37H21V36Z" fill="#919191"/><path d="M19 36H20V37H19V36Z" fill="#919191"/><path d="M17 36H18V37H17V36Z" fill="#919191"/><path d="M25 36H26V37H25V36Z" fill="#919191"/><path d="M23 36H24V37H23V36Z" fill="#919191"/><path d="M29 37H30V38H29V37Z" fill="#919191"/><path d="M28 38H29V39H28V38Z" fill="#919191"/><path d="M27 39H28V40H27V39Z" fill="#919191"/><path d="M36 14H37V16H36V14Z" fill="#919191"/><path d="M35 12H36V14H35V12Z" fill="#919191"/><path d="M34 11H35V12H34V11Z" fill="#919191"/><path d="M33 10H34V11H33V10Z" fill="#919191"/><path d="M30 8H31V9H30V8Z" fill="#919191"/><path d="M28 7H29V8H28V7Z" fill="#919191"/><path d="M32 9H33V10H32V9Z" fill="#919191"/><path d="M33 23H35V24H33V23Z" fill="#656565"/><path d="M36 25H37V27H36V25Z" fill="#656565"/><path d="M32 29H33V32H32V29Z" fill="#656565"/><path d="M37 23H38V25H37V23Z" fill="#656565"/><path d="M31 35H32V36H31V35Z" fill="#656565"/></svg>'
        // ));
    }

    function _clamp(uint256 value) private pure returns (uint8) {
        return value > 255 ? 255 : uint8(value);
    }

    function _generateHueRGB(uint256 seed) private pure returns (uint8 r, uint8 g, uint8 b) {
        // Use a better seed to ensure more variation
        uint256 hue = (seed * 137) % 360; // Use a prime number multiplier for better distribution
        uint256 saturation = 80 + (seed % 20); // 80-100% saturation
        uint256 lightness = 50 + (seed % 20); // 50-70% lightness

        // Convert HSL to RGB using a simpler approach
        uint256 c = (saturation * 255) / 100;
        uint256 m = (lightness * 255) / 100 - (c / 2);

        // Calculate which sextant of the color wheel we're in
        uint256 sextant = hue / 60;
        uint256 remainder = hue % 60;

        // Calculate the intermediate value
        uint256 x = (c * (60 - remainder)) / 60;

        if (sextant == 0) {
            return (_clamp(c + m), _clamp(x + m), _clamp(m));
        } else if (sextant == 1) {
            return (_clamp(x + m), _clamp(c + m), _clamp(m));
        } else if (sextant == 2) {
            return (_clamp(m), _clamp(c + m), _clamp(x + m));
        } else if (sextant == 3) {
            return (_clamp(m), _clamp(x + m), _clamp(c + m));
        } else if (sextant == 4) {
            return (_clamp(x + m), _clamp(m), _clamp(c + m));
        } else {
            return (_clamp(c + m), _clamp(m), _clamp(x + m));
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

    /// @notice Burns a token and updates circulating supply
    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        circulatingSupply--;
    }

    /// @notice Returns the ETH and USDC amounts redeemable per NFT
    /// @return ethShare Amount of ETH redeemable
    /// @return usdcShare Amount of USDC redeemable
    function getRedeemValue() public view returns (uint256 ethShare, uint256 usdcShare) {
        if (circulatingSupply == 0) {
            return (0, 0);
        }

        ethShare = address(this).balance / circulatingSupply;

        if (usdcContract != address(0)) {
            uint256 usdcBalance = IERC20(usdcContract).balanceOf(address(this));
            usdcShare = usdcBalance / circulatingSupply;
        }
    }

    /// @notice Returns the RGB color for a given tokenId
    function getHueRGB(uint256 tokenId) external view returns (uint8 r, uint8 g, uint8 b) {
        return _generateHueRGB(tokenId);
    }

    /// @notice Returns the current day since deployment (1-indexed)
    function day() external view returns (uint256) {
        return ((block.timestamp - deploymentTimestamp) / 1 days) + 1;
    }

    function _checkQuoterAndUSDC() private view {
        if (uniswapQuoter == address(0)) {
            revert UniswapQuoterNotConfigured();
        }
        if (usdcContract == address(0)) {
            revert USDCNotConfigured();
        }
    }

    function _checkLotteryConfigured() private view {
        if (lotteryContract == address(0)) {
            revert LotteryNotConfigured();
        }
    }

    /// @notice Purchase a lottery ticket for the current lottery round using ETH→USDC swap
    /// @dev Can only be called once per lottery round, automatically calculates spending amount
    function purchaseLotteryTicket() external whenNotPaused nonReentrant {
        _checkLotteryConfigured();

        // Check if USDC contract and quoter are configured
        _checkQuoterAndUSDC();

        // Get current lottery round based on lastJackpotEndTime and roundDurationInSeconds
        uint256 currentLotteryRound = getCurrentLotteryRound();

        // Check if lottery ticket was already purchased for this round
        if (lotteryPurchasedForDay[currentLotteryRound] > 0) {
            revert LotteryAlreadyPurchased();
        }

        // Get the amount to spend for this day (in ETH)
        uint256 dailyAmount = _getDailyPurchaseAmount();

        if (dailyAmount == 0) {
            revert InsufficientTreasury();
        }

        // Check if contract has enough ETH balance
        if (address(this).balance < dailyAmount) {
            revert InsufficientTreasury();
        }

        // Estimate USDC output using Uniswap V3 Quoter
        uint256 estimatedUSDC = _estimateUSDCForETH(dailyAmount);
        uint256 ticketPriceUSDC = LOTTERY_TICKET_PRICE_USD * (10 ** USDC_DECIMALS);
        if (estimatedUSDC < ticketPriceUSDC) {
            revert InsufficientUSDCForTicket();
        }

        // Update state first (before external calls)
        lotteryPurchasedForDay[currentLotteryRound] = dailyAmount;

        // Swap ETH to USDC using Uniswap V3
        uint256 usdcAmount = _swapETHForUSDC(dailyAmount);

        // Purchase lottery tickets using the lottery contract's purchaseTickets method
        // Parameters: (referrer, value, recipient)
        ILotteryContract(lotteryContract).purchaseTickets(
            lotteryReferrer, // referrer
            usdcAmount, // value
            address(this) // recipient (PotRaider contract)
        );

        emit LotteryTicketPurchased(currentLotteryRound, dailyAmount);
    }

    /// @notice Withdraw winnings from the lottery contract
    /// @dev Anyone can call this function to withdraw winnings
    function withdrawWinnings() external {
        _checkLotteryConfigured();

        // Call the lottery contract's withdrawWinnings method
        ILotteryContract(lotteryContract).withdrawWinnings();
    }

    /// @notice Get the current lottery round number
    /// @return The current lottery round number
    function getCurrentLotteryRound() public view returns (uint256) {
        _checkLotteryConfigured();

        ILotteryContract lottery = ILotteryContract(lotteryContract);
        uint256 lastJackpotEndTime = lottery.lastJackpotEndTime();
        uint256 roundDuration = lottery.roundDurationInSeconds();

        // If no jackpot has ended yet, we're in round 0
        if (lastJackpotEndTime == 0) {
            return 0;
        }

        // Calculate current round based on time elapsed since last jackpot end
        uint256 timeSinceLastJackpot = block.timestamp - lastJackpotEndTime;
        uint256 currentRound = timeSinceLastJackpot / roundDuration;

        return currentRound;
    }

    /// @notice Get the current lottery jackpot amount (LP pool total)
    /// @return The jackpot amount in USDC
    function getLotteryJackpot() external view returns (uint256) {
        _checkLotteryConfigured();
        return ILotteryContract(lotteryContract).lpPoolTotal();
    }

    /// @notice Get the amount of ETH that will be spent on the next lottery ticket purchase
    /// @return The amount in ETH (in wei) that will be spent
    function getDailyPurchaseAmount() external view returns (uint256) {
        return _getDailyPurchaseAmount();
    }

    function _getDailyPurchaseAmount() private view returns (uint256) {
        uint256 currentRound = getCurrentLotteryRound();
        uint256 roundDuration = ILotteryContract(lotteryContract).roundDurationInSeconds();
        uint256 totalRounds = (lotteryParticipationDays * 1 days) / roundDuration;
        uint256 remainingRounds = totalRounds > currentRound ? totalRounds - currentRound : 0;

        if (remainingRounds == 0) {
            return 0;
        }

        uint256 contractETHBalance = address(this).balance;
        uint256 ethPerRound = contractETHBalance / remainingRounds;

        uint256 estimatedUSDC = _estimateUSDCForETH(ethPerRound);
        uint256 ticketPriceUSDC = LOTTERY_TICKET_PRICE_USD * (10 ** USDC_DECIMALS);

        // Add a 2% buffer to the USDC check
        if (estimatedUSDC < (ticketPriceUSDC * 102) / 100) {
            return 0;
        }

        return ethPerRound;
    }

    /// @notice Set the lottery contract address
    /// @param _lotteryContract The address of the lottery contract
    function setLotteryContract(address _lotteryContract) external onlyOwner {
        lotteryContract = _lotteryContract;
        emit LotteryContractUpdated(_lotteryContract);
    }

    /// @notice Set the USDC contract address
    /// @param _usdcContract The address of the USDC contract
    function setUSDCContract(address _usdcContract) external onlyOwner {
        usdcContract = _usdcContract;
        emit USDCContractUpdated(_usdcContract);
    }

    /// @notice Set the Uniswap router address
    /// @param _uniswapRouter The address of the Uniswap V3 router
    function setUniswapRouter(address _uniswapRouter) external onlyOwner {
        uniswapRouter = _uniswapRouter;
    }

    /// @notice Set the Uniswap quoter address
    /// @param _uniswapQuoter The address of the Uniswap V3 quoter
    function setUniswapQuoter(address _uniswapQuoter) external onlyOwner {
        uniswapQuoter = _uniswapQuoter;
        emit UniswapQuoterUpdated(_uniswapQuoter);
    }

    /// @notice Internal function to swap ETH for USDC using Uniswap V3
    /// @param ethAmount The amount of ETH to swap
    /// @return usdcAmount The amount of USDC received
    function _swapETHForUSDC(uint256 ethAmount) internal returns (uint256 usdcAmount) {
        if (uniswapRouter == address(0)) {
            revert UniswapRouterNotConfigured();
        }
        if (usdcContract == address(0)) {
            revert USDCNotConfigured();
        }
        _checkWETHConfigured();
        // Create swap parameters
        uint256 estimatedUSDC = _estimateUSDCForETH(ethAmount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: wethAddress, // Use WETH address instead of address(0)
            tokenOut: usdcContract,
            fee: 500, // 0.05% fee tier
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes
            amountIn: ethAmount,
            amountOutMinimum: (estimatedUSDC * 95) / 100, // 5% slippage protection
            sqrtPriceLimitX96: 0
        });

        // Execute the swap
        usdcAmount = ISwapRouter(uniswapRouter).exactInputSingle{value: ethAmount}(params);

        return usdcAmount;
    }

    /// @notice Internal function to estimate USDC output for a given ETH amount using Uniswap V3 Quoter
    /// @param ethAmount The amount of ETH to estimate
    /// @return usdcAmount The estimated amount of USDC received
    function _estimateUSDCForETH(uint256 ethAmount) internal view returns (uint256 usdcAmount) {
        _checkQuoterAndUSDC();
        _checkWETHConfigured();
        // Uniswap V3 Quoter interface (minimal)
        (bool success, bytes memory data) = uniswapQuoter.staticcall(
            abi.encodeWithSignature(
                "quoteExactInputSingle(address,address,uint24,uint256,uint160)",
                wethAddress, // tokenIn (WETH)
                usdcContract, // tokenOut (USDC)
                500, // 0.05% fee tier
                ethAmount,
                0 // sqrtPriceLimitX96
            )
        );
        if (!success) {
            revert QuoterCallFailed();
        }
        usdcAmount = abi.decode(data, (uint256));
    }

    /// @notice Set the WETH address for Uniswap swaps
    /// @param _wethAddress The address of the WETH contract
    function setWETHAddress(address _wethAddress) external onlyOwner {
        wethAddress = _wethAddress;
    }

    /// @notice Set the lottery participation duration in days
    /// @param _lotteryParticipationDays The new lottery participation duration in days
    function setLotteryParticipationDays(uint256 _lotteryParticipationDays) external onlyOwner {
        require(_lotteryParticipationDays > 0, "Duration must be greater than 0");
        lotteryParticipationDays = _lotteryParticipationDays;
    }

    /// @notice Set the lottery referrer address
    /// @param _lotteryReferrer The new lottery referrer address
    function setLotteryReferrer(address _lotteryReferrer) external onlyOwner {
        lotteryReferrer = _lotteryReferrer;
        emit LotteryReferrerUpdated(_lotteryReferrer);
    }
}
