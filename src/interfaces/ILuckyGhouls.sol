// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ILuckyGhouls {
    /// @notice One Megapot ticket bought by the contract for a given drawing.
    struct PurchasedTicket {
        uint256 ticketId;
        uint8[5] normals;
        uint8 bonusball;
    }

    /// @notice Per-day purchase record, written once the full ticket target for a drawing is reached.
    struct DailyPurchase {
        uint256 ticketCount;
        uint256 drawingId;
        uint256 timestamp;
    }

    /// @notice A token was burned and its share of the treasury paid to its owner
    event TokenBurned(uint256 indexed tokenId, address indexed owner, uint256 ethPaid, uint256 usdcPaid);
    /// @notice A drawing's full ticket target was bought. `ethSpent` is the ETH swapped on the day's first call
    ///         (0 when the target is completed on a retry call).
    event TicketsPurchased(
        uint256 indexed purchaseDay, uint256 indexed drawingId, uint256 ticketsBoughtThisCall, uint256 ethSpent
    );
    /// @notice buyTickets stopped before the target (gas reserve hit or a purchase failed); call again to resume
    event TicketsPartiallyPurchased(uint256 indexed drawingId, uint256 ticketsBoughtThisCall, uint256 ticketsRemaining);
    /// @notice A single Megapot purchase reverted; `reason` is the raw revert data
    event TicketPurchaseFailed(uint256 indexed drawingId, uint256 ticketIndex, bytes reason);
    /// @notice No further unique number combination could be generated; the target was reduced to `ticketsBought`
    event UniqueTicketsExhausted(uint256 indexed drawingId, uint256 ticketsBought);
    /// @notice A drawing's tickets were claimed on Megapot and the USDC won was swapped to ETH
    event WinningsClaimed(uint256 indexed drawingId, uint256 ticketCount, uint256 usdcReceived, uint256 ethReceived);
    /// @notice The first completed purchase started the clock for burnRemainingTreasury
    event TreasuryBurnClockStarted(uint256 firstPurchaseTime, uint256 treasuryBurnUnlockTime);
    /// @notice The remaining treasury was sent to the BBITS burner
    event TreasuryBurned(uint256 ethBurned, uint256 timestamp);
    event MintBurnBpsUpdated(uint256 mintBurnBps);
    event MegapotReferrerUpdated(address indexed newReferrer);
    event MintPriceUpdated(uint256 mintPrice);
    event TotalPurchaseDaysUpdated(uint256 totalPurchaseDays);
    event PreferredNumbersUpdated(uint8[] preferredNumbers);
    event MinGasPerPurchaseUpdated(uint256 minGasPerPurchase);

    error QuantityZero();
    error MaxMintPerCallExceeded();
    error MaxSupplyReached();
    error InsufficientPayment();
    error TransferFailed();
    error InvalidPercentage();
    error NotOwner();
    error NoTreasuryAvailable();
    error TicketsAlreadyPurchased();
    error InsufficientUSDCForTicket();
    error InsufficientTreasury();
    error NoTicketsForDrawing();
    error DrawingNotSettled();
    error InvalidPreferredNumber();
    error TreasuryBurnLocked();
    error NothingToBurn();

    function megapotReferrer() external view returns (address);
}
