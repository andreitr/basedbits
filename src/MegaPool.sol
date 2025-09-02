// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IBaseJackpot} from "@src/interfaces/baseJackpot/IBaseJackpot.sol";

/// @title MegaPool
/// @notice Buys Megapot lottery tickets immediately by pulling USDC from the caller; the contract only holds funds when claiming winnings.
contract MegaPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IBaseJackpot public immutable lottery;

    /// @notice Optional referrer address for lottery purchases
    address public lotteryReferrer;

    /// @notice Number of purchases made per lottery day (keyed by round start timestamp)
    mapping(uint256 => uint256) public dailyPurchaseCount;
    /// @notice Addresses that triggered purchases per lottery day (keyed by round start timestamp)
    mapping(uint256 => address[]) public dailyPurchasers;

    event Purchased(address indexed buyer, uint256 day, uint256 amount);
    event WinningsClaimed(uint256 amount);

    error AmountZero();
    // No deposits/withdrawals: contract should not hold funds except winnings

    constructor(IERC20 _usdc, IBaseJackpot _lottery, address _owner) Ownable(_owner) {
        usdc = _usdc;
        lottery = _lottery;

        usdc.approve(address(_lottery), type(uint256).max);
    }

    /// @notice Set the referrer used for lottery purchases
    function setLotteryReferrer(address _referrer) external onlyOwner {
        lotteryReferrer = _referrer;
    }

    /// @notice Purchase lottery tickets immediately using caller-provided USDC
    /// @param amount Amount of USDC to spend on tickets
    function buy(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        // Pull USDC from the buyer and immediately purchase tickets.
        // The lottery contract uses allowance to transfer USDC from this contract.
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        uint256 dayKey = _currentLotteryDayKey();
        dailyPurchaseCount[dayKey] += 1;
        dailyPurchasers[dayKey].push(msg.sender);

        lottery.purchaseTickets(lotteryReferrer, amount, address(this));

        emit Purchased(msg.sender, dayKey, amount);
    }

    /// @notice Claim winnings from the Megapot lottery
    function claimWinnings() external nonReentrant {
        uint256 beforeBal = usdc.balanceOf(address(this));
        lottery.withdrawWinnings();
        uint256 gained = usdc.balanceOf(address(this)) - beforeBal;
        emit WinningsClaimed(gained);
    }

    /// VIEW HELPERS ///

    /// @notice Returns the current lottery day key (round start timestamp) used for indexing daily stats
    /// @dev Uses lottery's last end time and round duration to align 24h windows
    function currentLotteryDayKey() external view returns (uint256) {
        return _currentLotteryDayKey();
    }

    /// @notice Returns the current lottery window start and end timestamps
    function currentLotteryWindow() external view returns (uint256 start, uint256 end) {
        (start, end) = _currentLotteryWindow();
    }

    /// INTERNAL ///

    function _currentLotteryDayKey() internal view returns (uint256) {
        (uint256 start,) = _currentLotteryWindow();
        return start;
    }

    function _currentLotteryWindow() internal view returns (uint256 start, uint256 end) {
        uint256 duration = lottery.roundDurationInSeconds();
        if (duration == 0) {
            duration = 1 days; // fallback to 24h if not provided
        }
        uint256 lastEnd = lottery.lastJackpotEndTime();

        // If timestamp is before the last recorded end, consider the window ending at lastEnd
        // and starting duration before it.
        if (block.timestamp <= lastEnd) {
            start = lastEnd - duration;
            end = lastEnd;
            return (start, end);
        }

        uint256 elapsed = block.timestamp - lastEnd;
        uint256 k = elapsed / duration; // number of full periods since last end
        start = lastEnd + k * duration;
        end = start + duration;
    }

}
