// SPDX-License-Identifier: MIT
// TEST DEPLOYMENT ONLY - DO NOT USE FOR PRODUCTION
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
    uint256 private nextTokenId;
    address public wethAddress;
    address public immutable artist;
    uint16 public artistPercentage;
    string public contractMetadataURI;
    uint256 public immutable deploymentTimestamp;
    uint256 public lotteryParticipationDays = 365;
    uint256 public constant LOTTERY_TICKET_PRICE_USD = 1;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant MAX_MINT_PER_CALL = 50;
    address public lotteryContract;
    address public usdcContract;
    address public uniswapRouter;
    address public uniswapQuoter;
    mapping(uint256 => uint256) public lotteryPurchasedForDay;
    address public lotteryReferrer;
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
    constructor(
        uint256 _mintPrice,
        address _burnerContract,
        address _artist
    ) ERC721("Pot Raider Test", "POTRAIDERTEST") Ownable(msg.sender) {
        mintPrice = _mintPrice;
        burnerContract = _burnerContract;
        artist = _artist;
        artistPercentage = 1000; // 10%
        burnPercentage = 1000; // 10%
        deploymentTimestamp = block.timestamp;
    }
} 