// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IBaseJackpot} from "@src/interfaces/baseJackpot/IBaseJackpot.sol";

/// @title MegaPool
/// @notice Allows users to pool USDC funds to purchase Megapot lottery tickets
contract MegaPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IBaseJackpot public immutable lottery;

    /// @notice Optional referrer address for lottery purchases
    address public lotteryReferrer;

    /// @notice Amount of USDC each depositor has provided
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;

    /// @notice Number of purchases made each day
    mapping(uint256 => uint256) public dailyPurchaseCount;
    /// @notice Addresses that triggered purchases each day
    mapping(uint256 => address[]) public dailyPurchasers;

    event Deposited(address indexed user, uint256 amount);
    event Purchased(address indexed buyer, uint256 day, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event WinningsClaimed(uint256 amount);

    error AmountZero();
    error InsufficientBalance();
    error NothingToWithdraw();

    constructor(IERC20 _usdc, IBaseJackpot _lottery, address _owner) Ownable(_owner) {
        usdc = _usdc;
        lottery = _lottery;

        usdc.approve(address(_lottery), type(uint256).max);
    }

    /// @notice Set the referrer used for lottery purchases
    function setLotteryReferrer(address _referrer) external onlyOwner {
        lotteryReferrer = _referrer;
    }

    /// @notice Deposit USDC into the pool
    /// @param amount Amount of USDC to deposit
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();

        deposits[msg.sender] += amount;
        totalDeposits += amount;

        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, amount);
    }

    /// @notice Purchase lottery tickets using pooled funds
    /// @param amount Amount of USDC to spend on tickets
    function buy(uint256 amount) external nonReentrant {
        if (amount == 0) revert AmountZero();
        if (usdc.balanceOf(address(this)) < amount) revert InsufficientBalance();

        uint256 day = block.timestamp / 1 days;
        dailyPurchaseCount[day] += 1;
        dailyPurchasers[day].push(msg.sender);

        lottery.purchaseTickets(lotteryReferrer, amount, address(this));

        emit Purchased(msg.sender, day, amount);
    }

    /// @notice Claim winnings from the Megapot lottery
    function claimWinnings() external nonReentrant {
        uint256 beforeBal = usdc.balanceOf(address(this));
        lottery.withdrawWinnings();
        uint256 gained = usdc.balanceOf(address(this)) - beforeBal;
        emit WinningsClaimed(gained);
    }

    /// @notice Withdraw the caller's share of the pool's balance
    function withdraw() external nonReentrant {
        uint256 userDeposit = deposits[msg.sender];
        if (userDeposit == 0) revert NothingToWithdraw();

        uint256 poolBalance = usdc.balanceOf(address(this));
        uint256 amount = (poolBalance * userDeposit) / totalDeposits;

        deposits[msg.sender] = 0;
        totalDeposits -= userDeposit;

        usdc.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }
}
