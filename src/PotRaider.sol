// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721Burnable, ERC721} from "@openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {BBitsBurner} from "src/BBitsBurner.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IBaseJackpot} from "@src/interfaces/baseJackpot/IBaseJackpot.sol";
import {IPotRaider} from "@src/interfaces/IPotRaider.sol";

contract PotRaider is IPotRaider, ERC721Burnable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable weth;

    IERC20 public immutable usdc;

    BBitsBurner public immutable bbitsBurner;

    /// @notice Uniswap V3 Router for ETH→USDC swaps
    IV3Router public immutable uniswapRouter;

    /// @notice Uniswap V3 Quoter for ETH→USDC estimation
    IV3Quoter public immutable uniswapQuoter;

    IBaseJackpot public immutable lottery;

    uint256 public immutable lotteryTicketPriceUSD;

    uint256 public immutable maxMint;

    uint256 public totalSupply;

    uint256 public circulatingSupply;

    uint256 public mintPrice;

    /// @dev 10_000 = 100%
    uint256 public burnPercentage;


    /// @notice OpenSea-style contract-level metadata URI
    string public contractURI;

    /// @notice Referrer address for lottery ticket purchases
    address public lotteryReferrer;

    /// @notice Lottery ticket purchase system variables
    uint256 public lotteryParticipationDays;

    /// @dev Internal counter to track number of lottery days entered
    uint256 public currentLotteryDay;

    struct LotteryPurchase {
        uint256 tickets;
        uint256 timestamp;
    }

    mapping(uint256 => LotteryPurchase) public lotteryPurchaseHistory;

    constructor(
        address _owner,
        uint256 _mintPrice,
        BBitsBurner _bbitsBurner,
        IERC20 _weth,
        IERC20 _usdc,
        IV3Router _router,
        IV3Quoter _quoter,
        IBaseJackpot _lottery
    ) ERC721("Pot Raider", "POTRAIDER") Ownable(_owner) {
        mintPrice = _mintPrice;
        bbitsBurner = _bbitsBurner;
        weth = _weth;
        usdc = _usdc;
        uniswapRouter = _router;
        uniswapQuoter = _quoter;
        lottery = _lottery;

        burnPercentage = 2000; // 20%
        lotteryTicketPriceUSD = 1e6; // $1 per ticket
        maxMint = 50;
        lotteryParticipationDays = 365;

        usdc.approve(address(lottery), type(uint256).max);
    }

    /// EXTERNAL ///

    receive() external payable {}

    function mint(uint256 quantity) external payable whenNotPaused nonReentrant {
        if (quantity == 0) revert QuantityZero();
        if (quantity > maxMint) revert MaxMintPerCallExceeded();
        if (msg.value < mintPrice * quantity) revert InsufficientPayment();

        uint256 burnAmount = (msg.value * burnPercentage) / 10_000;

        // Send burn amount to burner contract
        if (burnAmount > 0) bbitsBurner.burn{value: burnAmount}(0);

        for (uint256 i = 0; i < quantity; i++) {
            _mint(msg.sender, totalSupply);
            totalSupply++;
            circulatingSupply++;
        }
    }

    function exchange(uint256 tokenId) external whenNotPaused nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        // Calculate shares
        uint256 ethShare = address(this).balance / circulatingSupply;
        uint256 usdcShare = usdc.balanceOf(address(this)) / circulatingSupply;
        if (ethShare == 0 && usdcShare == 0) revert NoTreasuryAvailable();

        // Burn the NFT first (state update before external calls)
        burn(tokenId);

        // Send USDC share to the owner (if any), but only if balance is sufficient
        if (usdcShare > 0) usdc.safeTransfer(msg.sender, usdcShare);

        // Send ETH share to the owner
        (bool success,) = msg.sender.call{value: ethShare}("");
        if (!success) revert TransferFailed();

        emit NFTExchanged(tokenId, msg.sender, ethShare, usdcShare);
    }

    /// @notice Burns a token and updates circulating supply
    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        circulatingSupply--;
    }

    /// @notice Purchase a lottery ticket for the current lottery round using ETH→USDC swap
    /// @dev Can only be called once per lottery round, automatically calculates spending amount
    function purchaseLotteryTicket() external whenNotPaused nonReentrant {
        // Check if lottery ticket was already purchased for this round
        (,, bool active) = lottery.usersInfo(address(this));
        if (active) revert LotteryAlreadyPurchased();

        // Get the amount to spend for this day (in ETH)
        uint256 dailyAmount = getDailyPurchaseAmount();
        if (dailyAmount == 0) revert InsufficientTreasury();

        // Swap ETH to USDC using Uniswap V3
        uint256 usdcAmount = _swapETHForUSDC(dailyAmount);

        // Calculate number of whole tickets purchased
        uint256 tickets = usdcAmount / lotteryTicketPriceUSD;
        if (tickets == 0) revert InsufficientUSDCForTicket();

        // Record lottery purchase information in tickets and timestamp
        lotteryPurchaseHistory[currentLotteryDay] = LotteryPurchase({
            tickets: tickets,
            timestamp: block.timestamp
        });

        // Purchase only the number of full tickets
        uint256 spendAmount = tickets * lotteryTicketPriceUSD;
        lottery.purchaseTickets(lotteryReferrer, spendAmount, address(this));

        // Update lottery counter
        currentLotteryDay++;
        emit LotteryTicketPurchased(currentLotteryDay, dailyAmount);
    }

    /// @notice Withdraw winnings from the lottery contract
    /// @dev Anyone can call this function
    function withdrawWinnings() external whenNotPaused nonReentrant {
        lottery.withdrawWinnings();
    }

    /// @notice Withdraw referral fees from the lottery contract
    /// @dev Anyone can call this function
    function withdrawReferralFees() external whenNotPaused nonReentrant {
        lottery.withdrawReferralFees();
    }

    /// SETTINGS ///

    /// @notice Emergency withdraw of ETH or ERC20 tokens
    /// @param token Address of the token to withdraw, or address(0) for ETH
    function emergencyWithdraw(address token) external onlyOwner nonReentrant {
        if (token == address(0)) {
            (bool success,) = owner().call{value: address(this).balance}("");
            if (!success) revert TransferFailed();
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(owner(), bal);
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets the contract-level metadata URI (e.g., OpenSea contract metadata)
    /// @dev Not emitting event given potential size of string
    function setContractURI(string calldata _uri) external onlyOwner {
        contractURI = _uri;
    }

    /// @notice Set the lottery participation duration in days
    /// @param _lotteryParticipationDays The new lottery participation duration in days
    function setLotteryParticipationDays(uint256 _lotteryParticipationDays) external onlyOwner {
        if (_lotteryParticipationDays == 0) revert QuantityZero();
        lotteryParticipationDays = _lotteryParticipationDays;
        emit LotteryParticipationDaysUpdated(_lotteryParticipationDays);
    }

    /// @notice Set the lottery referrer address
    /// @param _lotteryReferrer The new lottery referrer address
    function setLotteryReferrer(address _lotteryReferrer) external onlyOwner {
        lotteryReferrer = _lotteryReferrer;
        emit LotteryReferrerUpdated(_lotteryReferrer);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    /// @notice Update the burn percentage
    /// @param _burnPercentage New burn percentage (10_000 = 100%)
    function setBurnPercentage(uint16 _burnPercentage) external onlyOwner {
        if (_burnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _burnPercentage;
        emit BurnPercentageUpdated(_burnPercentage);
    }

    /// INTERNAL ///

    /// @notice Internal function to swap ETH for USDC using Uniswap V3
    /// @param ethAmount The amount of ETH to swap
    /// @return usdcAmount The amount of USDC received
    function _swapETHForUSDC(uint256 ethAmount) internal returns (uint256 usdcAmount) {
        uint256 estimatedUSDCAmount = _estimateUSDCForETH(ethAmount);
        IV3Router.ExactInputSingleParams memory params = IV3Router.ExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            fee: 500,
            recipient: address(this),
            amountIn: ethAmount,
            amountOutMinimum: (estimatedUSDCAmount * 95) / 100,
            sqrtPriceLimitX96: 0
        });
        usdcAmount = uniswapRouter.exactInputSingle{value: ethAmount}(params);
    }

    /// @notice Internal function to estimate USDC output for a given ETH amount using Uniswap V3 Quoter
    /// @param ethAmount The amount of ETH to estimate
    /// @return estimatedUSDCAmount The estimated amount of USDC received
    function _estimateUSDCForETH(uint256 ethAmount) internal returns (uint256 estimatedUSDCAmount) {
        IV3Quoter.QuoteExactInputSingleParams memory params = IV3Quoter.QuoteExactInputSingleParams({
            tokenIn: address(weth),
            tokenOut: address(usdc),
            amountIn: ethAmount,
            fee: 500,
            sqrtPriceLimitX96: 0
        });
        (estimatedUSDCAmount,,,) = uniswapQuoter.quoteExactInputSingle(params);
    }

    function _generateTokenURI(uint256 tokenId) internal pure returns (string memory) {
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
        (uint8 r, uint8 g, uint8 b) = getHueRGB(tokenId);

        string memory backgroundColor = string(
            abi.encodePacked("rgb(", Strings.toString(r), ",", Strings.toString(g), ",", Strings.toString(b), ")")
        );
                
        return string(abi.encodePacked(
            '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="',
            backgroundColor,'"/><rect width="48" height="48" fill="black" opacity="0.8"/><path d="M15 32H16V37H17V34H18V37H19V34H20V37H21V34H22V37H23V34H24V37H25V34H26V37H27V34H28V36H29V34H30V30H31V31H32V29H33V32H32V36H31V37H30V38H29V39H28V40H16V39H15V32Z" fill="white"/><path d="M34 29V28H32V29H30V28H28V30H27V31H26V30H25V31H24V30H23V31H22V30H21V31H20V30H19V31H18V30H17V31H16V30H15V31H14V30H13V28H11V27H10V24H11V15H12V13H13V11H14V10H15V9H16V8H18V7H29V8H31V9H33V10H34V11H35V12H36V14H37V16H38V25H37V27H36V28H35V29H34Z" fill="white"/><path d="M21 24V27H20V26H19V27H18V24H19V23H20V24H21Z" fill="#1E1E1E"/><path d="M21 23V19H22V18H23V17H24V16H28V17H29V18H30V19H31V24H30V25H29V26H24V25H23V24H22V23H21Z" fill="black"/><path d="M23 18H24V17H28V18H29V19H30V23H29V24H28V25H24V24H23V23H22V19H23V18Z" fill="#FEC94F"/><path d="M24 18H28V19H24V18Z" fill="#EA9412"/><path d="M24 23H28V24H24V23Z" fill="#EA9412"/><path d="M23 19H24V23H23V19Z" fill="#EA9412"/><path d="M28 19H29V23H28V19Z" fill="#EA9412"/><path d="M25 20H27V22H25V20Z" fill="#EA9412"/><rect x="25" y="20" width="1" height="1" fill="white"/><path d="M8 23V19H9V18H10V17H11V16H15V17H16V18H17V19H18V24H17V25H16V26H11V25H10V24H9V23H8Z" fill="black"/><path d="M10 18H11V17H15V18H16V19H17V23H16V24H15V25H11V24H10V23H9V19H10V18Z" fill="#FEC94F"/><path d="M11 18H15V19H11V18Z" fill="#EA9412"/><path d="M11 23H15V24H11V23Z" fill="#EA9412"/><path d="M10 19H11V23H10V19Z" fill="#EA9412"/><path d="M15 19H16V23H15V19Z" fill="#EA9412"/><path d="M12 20H14V22H12V20Z" fill="#EA9412"/><rect x="12" y="20" width="1" height="1" fill="white"/><path d="M13 11H14V13H13V11Z" fill="#E9E9E9"/><path d="M12 13H13V14H15V15H12V13Z" fill="#E9E9E9"/><path d="M15 15H16V16H15V15Z" fill="#E9E9E9"/><path d="M11 15H12V16H11V15Z" fill="#E9E9E9"/><path d="M23 14H24V15H23V14Z" fill="#E9E9E9"/><path d="M24 13H28V14H24V13Z" fill="#E9E9E9"/><path d="M21 23H22V24H21V23Z" fill="#E9E9E9"/><path d="M20 18H21V16H22V15H23V16H24V17H23V18H22V19H21V23H20V18Z" fill="#E9E9E9"/><path d="M17 24H18V25H17V24Z" fill="#E9E9E9"/><path d="M22 24H23V25H22V24Z" fill="#E9E9E9"/><path d="M16 28H17V29H16V28Z" fill="#E9E9E9"/><path d="M20 28H21V29H20V28Z" fill="#E9E9E9"/><path d="M18 28H19V29H18V28Z" fill="#E9E9E9"/><path d="M22 28H23V29H22V28Z" fill="#E9E9E9"/><path d="M29 25H30V26H29V25Z" fill="#E9E9E9"/><path d="M30 24H31V25H30V24Z" fill="#E9E9E9"/><path d="M19 18V24H18V19H17V18H19Z" fill="#E9E9E9"/><path d="M16 16H17V17H16V16Z" fill="#E9E9E9"/><path d="M14 10H15V11H14V10Z" fill="#E9E9E9"/><path d="M15 9H16V10H15V9Z" fill="#E9E9E9"/><path d="M16 8H18V9H16V8Z" fill="#E9E9E9"/><path d="M29 7H18V8H27V9H28V10H29V11H30V12H31V14H28V17H29V18H30V19H32V24H34V25H33V26H32V27H29V26H24V25H23V27H24V29H26V31H27V30H28V28H30V29H32V28H34V29H35V28H36V27H37V25H38V16H37V14H36V12H35V11H34V10H33V9H31V8H29V7Z" fill="#E9E9E9"/><path d="M17 25H16V26H12V27H11V28H13V30H14V31H15V30H16V29H15V28H16V27H17V25Z" fill="#E9E9E9"/><path d="M33 32V29H32V31H31V30H30V34H29V36H28V34H27V37H26V34H25V37H24V34H23V37H22V34H21V37H20V34H19V37H18V34H17V37H16V32H15V38H21V39H25V40H28V39H29V38H30V37H31V36H32V32H33Z" fill="#E9E9E9"/><path d="M26 7H29V8H26V7Z" fill="#B9B9B9"/><path d="M29 8H31V9H29V8Z" fill="#B9B9B9"/><path d="M31 9H33V10H31V9Z" fill="#B9B9B9"/><path d="M33 10H34V11H33V10Z" fill="#B9B9B9"/><path d="M34 11H35V12H34V11Z" fill="#B9B9B9"/><path d="M11 15H12V16H11V15Z" fill="#B9B9B9"/><path d="M12 13H13V15H12V13Z" fill="#B9B9B9"/><path d="M24 26H29V27H28V28H25V27H24V26Z" fill="#B9B9B9"/><path d="M29 25H30V26H29V25Z" fill="#B9B9B9"/><path d="M30 28H32V29H30V28Z" fill="#B9B9B9"/><path d="M30 30H31V31H32V36H31V32H30V30Z" fill="#B9B9B9"/><path d="M30 24H31V25H30V24Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#B9B9B9"/><path d="M29 17H30V18H29V17Z" fill="#B9B9B9"/><path d="M28 16H29V17H28V16Z" fill="#B9B9B9"/><path d="M28 14H29V15H28V14Z" fill="#B9B9B9"/><path d="M29 15H30V16H29V15Z" fill="#B9B9B9"/><path d="M30 16H31V17H30V16Z" fill="#B9B9B9"/><path d="M20 19H21V22H20V19Z" fill="#B9B9B9"/><path d="M18 19H19V22H18V19Z" fill="#B9B9B9"/><path d="M17 18H18V19H17V18Z" fill="#B9B9B9"/><path d="M16 17H17V18H16V17Z" fill="#B9B9B9"/><path d="M15 16H16V17H15V16Z" fill="#B9B9B9"/><path d="M21 17H22V16H24V17H23V18H22V19H21V17Z" fill="#B9B9B9"/><path d="M26 30H27V31H26V30Z" fill="#B9B9B9"/><path d="M17 35H18V37H19V35H20V37H21V35H22V37H23V35H24V37H25V35H26V37H27V35H28V36H29V34H30V36H31V37H30V38H29V39H28V38H17V35Z" fill="#B9B9B9"/><path d="M15 32H16V35H15V32Z" fill="#B9B9B9"/><path d="M26 39H28V40H26V39Z" fill="#B9B9B9"/><path d="M12 26H16V27H15V28H14V30H13V28H11V27H12V26Z" fill="#B9B9B9"/><path d="M35 12H36V14H35V12Z" fill="#B9B9B9"/><path d="M36 14H37V16H36V14Z" fill="#B9B9B9"/><path d="M37 16H38V25H37V27H36V28H35V29H34V28H32V26H33V25H34V24H33V23H32V20H33V19H35V17H36V18H37V16Z" fill="#B9B9B9"/><path d="M23 25H24V26H23V25Z" fill="#B9B9B9"/><path d="M30 18H31V19H30V18Z" fill="#919191"/><path d="M30 16H31V17H30V16Z" fill="#919191"/><path d="M29 15H30V16H29V15Z" fill="#919191"/><path d="M28 16H29V17H28V16Z" fill="#919191"/><path d="M29 17H30V18H29V17Z" fill="#919191"/><path d="M22 17H23V18H22V17Z" fill="#919191"/><path d="M16 17H17V18H16V17Z" fill="#919191"/><path d="M13 26H15V27H14V28H13V26Z" fill="#919191"/><path d="M17 28H18V30H17V28Z" fill="#919191"/><path d="M15 28H16V30H15V28Z" fill="#919191"/><path d="M19 28H20V30H19V28Z" fill="#919191"/><path d="M21 28H22V30H21V28Z" fill="#919191"/><path d="M23 28H24V30H23V28Z" fill="#919191"/><path d="M25 26H28V27H29V28H28V30H27V27H25V26Z" fill="#919191"/><path d="M25 28H26V30H25V28Z" fill="#919191"/><path d="M23 16H24V17H23V16Z" fill="#919191"/><path d="M32 24V21H33V22H36V24H32Z" fill="#919191"/><path d="M33 25H36V24H37V16H38V25H37V27H36V28H35V29H34V27H32V26H33V25Z" fill="#919191"/><path d="M30 35H31V31H32V29H33V32H32V36H31V37H30V35Z" fill="#919191"/><path d="M29 34H30V35H29V34Z" fill="#919191"/><path d="M27 36H28V37H27V36Z" fill="#919191"/><path d="M21 36H22V37H21V36Z" fill="#919191"/><path d="M19 36H20V37H19V36Z" fill="#919191"/><path d="M17 36H18V37H17V36Z" fill="#919191"/><path d="M25 36H26V37H25V36Z" fill="#919191"/><path d="M23 36H24V37H23V36Z" fill="#919191"/><path d="M29 37H30V38H29V37Z" fill="#919191"/><path d="M28 38H29V39H28V38Z" fill="#919191"/><path d="M27 39H28V40H27V39Z" fill="#919191"/><path d="M36 14H37V16H36V14Z" fill="#919191"/><path d="M35 12H36V14H35V12Z" fill="#919191"/><path d="M34 11H35V12H34V11Z" fill="#919191"/><path d="M33 10H34V11H33V10Z" fill="#919191"/><path d="M30 8H31V9H30V8Z" fill="#919191"/><path d="M28 7H29V8H28V7Z" fill="#919191"/><path d="M32 9H33V10H32V9Z" fill="#919191"/><path d="M33 23H35V24H33V23Z" fill="#656565"/><path d="M36 25H37V27H36V25Z" fill="#656565"/><path d="M32 29H33V32H32V29Z" fill="#656565"/><path d="M37 23H38V25H37V23Z" fill="#656565"/><path d="M31 35H32V36H31V35Z" fill="#656565"/></svg>'
        ));
    }

    function _clamp(uint256 value) internal pure returns (uint8) {
        return value > 255 ? 255 : uint8(value);
    }

    function getHueRGB(uint256 seed) internal pure returns (uint8 r, uint8 g, uint8 b) {
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

    /// VIEW ///

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return _generateTokenURI(tokenId);
    }

    /// @notice Returns the ETH and USDC amounts redeemable per NFT
    /// @return ethShare Amount of ETH redeemable
    /// @return usdcShare Amount of USDC redeemable
    function getRedeemValue() public view returns (uint256 ethShare, uint256 usdcShare) {
        if (circulatingSupply == 0) {
            return (0, 0);
        }

        ethShare = address(this).balance / circulatingSupply;

        if (address(usdc) != address(0)) {
            uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
            usdcShare = usdcBalance / circulatingSupply;
        }

        return (ethShare, usdcShare);
    }

    /// @notice Get the amount of ETH that will be spent on the next lottery ticket purchase
    /// @return ethPerDay The amount in ETH (in wei) that will be spent
    function getDailyPurchaseAmount() public view returns (uint256 ethPerDay) {
        uint256 remainingDays = lotteryParticipationDays - currentLotteryDay;
        uint256 contractETHBalance = address(this).balance;
        if (remainingDays == 0 || contractETHBalance == 0) return 0;
        ethPerDay = contractETHBalance / remainingDays;
    }

    /// @notice Get the current lottery jackpot amount (LP pool total)
    /// @return jackPot The jackpot amount in USDC
    function getLotteryJackpot() external view returns (uint256 jackPot) {
        jackPot = lottery.lpPoolTotal();
    }
    /// @notice Get the last lottery jackpot end time
    /// @return endTime The last lottery jackpot end time

    function getLotterylastJackpotEndTime() external view returns (uint256 endTime) {
        endTime = lottery.lastJackpotEndTime();
    }
    /// @notice Get the lottery round duration in seconds
    /// @return duration The lottery round duration in seconds

    function getLotteryroundDurationInSeconds() external view returns (uint256 duration) {
        duration = lottery.roundDurationInSeconds();
    }
}
