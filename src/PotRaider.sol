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
import {PotRaiderArt} from "@src/modules/PotRaiderArt.sol";

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

    PotRaiderArt public immutable artContract;

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
        IBaseJackpot _lottery,
        PotRaiderArt _artContract
    ) ERC721("Pot Raider", "POTRAIDER") Ownable(_owner) {
        mintPrice = _mintPrice;
        bbitsBurner = _bbitsBurner;
        weth = _weth;
        usdc = _usdc;
        uniswapRouter = _router;
        uniswapQuoter = _quoter;
        lottery = _lottery;
        artContract = _artContract;

        burnPercentage = 2000; // 20%
        lotteryTicketPriceUSD = 1e6; // $1 per ticket
        maxMint = 50;
        lotteryParticipationDays = 365;

        usdc.approve(address(lottery), type(uint256).max);
        usdc.approve(address(uniswapRouter), type(uint256).max);
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
        lotteryPurchaseHistory[currentLotteryDay] = LotteryPurchase({tickets: tickets, timestamp: block.timestamp});

        // Purchase only the number of full tickets
        uint256 spendAmount = tickets * lotteryTicketPriceUSD;
        lottery.purchaseTickets(lotteryReferrer, spendAmount, address(this));

        // Swap any leftover USDC back to ETH
        uint256 leftoverUSDC = usdc.balanceOf(address(this));
        if (leftoverUSDC > 0) {
            _swapUSDCforETH(leftoverUSDC);
        }

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

    /// @notice Internal function to swap USDC for ETH using Uniswap V3
    /// @param usdcAmount The amount of USDC to swap
    /// @return ethAmount The amount of ETH received
    function _swapUSDCforETH(uint256 usdcAmount) internal returns (uint256 ethAmount) {
        uint256 estimatedETHAmount = _estimateETHForUSDC(usdcAmount);
        IV3Router.ExactInputSingleParams memory params = IV3Router.ExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(weth),
            fee: 500,
            recipient: address(this),
            amountIn: usdcAmount,
            amountOutMinimum: (estimatedETHAmount * 95) / 100,
            sqrtPriceLimitX96: 0
        });
        ethAmount = uniswapRouter.exactInputSingle(params);
        // unwrap WETH to ETH
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = address(weth).call(abi.encodeWithSignature("withdraw(uint256)", ethAmount));
        require(success, "WETH withdraw failed");
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

    /// @notice Internal function to estimate ETH output for a given USDC amount using Uniswap V3 Quoter
    /// @param usdcAmount The amount of USDC to estimate
    /// @return estimatedETHAmount The estimated amount of ETH received
    function _estimateETHForUSDC(uint256 usdcAmount) internal returns (uint256 estimatedETHAmount) {
        IV3Quoter.QuoteExactInputSingleParams memory params = IV3Quoter.QuoteExactInputSingleParams({
            tokenIn: address(usdc),
            tokenOut: address(weth),
            amountIn: usdcAmount,
            fee: 500,
            sqrtPriceLimitX96: 0
        });
        (estimatedETHAmount,,,) = uniswapQuoter.quoteExactInputSingle(params);
    }



    /// VIEW ///

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return artContract.generateTokenURI(tokenId);
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
