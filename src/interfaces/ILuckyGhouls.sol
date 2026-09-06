// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ILuckyGhouls {
    /// @notice One Megapot ticket bought by the contract for a given drawing.
    struct PurchasedTicket {
        uint256 ticketId;
        uint8[5] normals;
        uint8 bonusball;
    }

    /// @notice Per-ritual-day record, written once the full ticket target for a drawing is reached.
    struct RitualPurchase {
        uint256 ticketCount;
        uint256 drawingId;
        uint256 timestamp;
    }

    event PactBroken(uint256 indexed tokenId, address indexed owner, uint256 ethAmount, uint256 usdcAmount);
    event NightlyRitualPerformed(
        uint256 indexed day, uint256 indexed drawingId, uint256 ticketsBoughtThisCall, uint256 ethSpent
    );
    event NightlyRitualPartiallyPerformed(
        uint256 indexed drawingId, uint256 ticketsBoughtThisCall, uint256 ticketsRemaining
    );
    event TicketPurchaseFailed(uint256 indexed drawingId, uint256 ticketIndex, bytes reason);
    event EvilTicketSpaceExhausted(uint256 indexed drawingId, uint256 ticketsSecured);
    event ReckoningClaimed(uint256 indexed drawingId, uint256 ticketCount, uint256 usdcReceived);
    event BurnPercentageUpdated(uint256 burnPercentage);
    event RitualReferrerUpdated(address indexed newReferrer);
    event SummoningPriceUpdated(uint256 mintPrice);
    event RitualParticipationDaysUpdated(uint256 ritualParticipationDays);
    event EvilNumbersUpdated(uint8[] evilNumbers);
    event RitualGasReserveUpdated(uint256 ritualGasReserve);

    error QuantityZero();
    error MaxMintPerCallExceeded();
    error MaxSupplyReached();
    error InsufficientPayment();
    error TransferFailed();
    error InvalidPercentage();
    error NotOwner();
    error NoTreasuryAvailable();
    error RitualAlreadyPerformed();
    error InsufficientUSDCForTicket();
    error InsufficientTreasury();
    error NoTicketsForDrawing();
    error DrawingNotSettled();
    error InvalidEvilNumber();

    function lotteryReferrer() external view returns (address);
}
