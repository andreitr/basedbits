// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/// @title  Megapot V2 Jackpot interface (Base mainnet: 0x3bAe643002069dBCbcd62B1A4eb4C4A397d042a2)
/// @notice Minimal subset of the deployed Jackpot ABI used by Lucky Ghouls. Struct field order matches the
///         deployed contract exactly and must not be reordered.
interface IJackpot {
    struct Ticket {
        uint8[] normals; // exactly 5, unique, each in [1..ballMax]
        uint8 bonusball; // in [1..bonusballMax]
    }

    struct DrawingState {
        uint256 prizePool;
        uint256 ticketPrice;
        uint256 edgePerTicket;
        uint256 referralWinShare;
        uint256 referralFee;
        uint256 globalTicketsBought;
        uint256 lpEarnings;
        uint256 drawingTime;
        uint256 winningTicket;
        uint8 ballMax;
        uint8 bonusballMax;
        address payoutCalculator;
        bool jackpotLock;
    }

    /// @notice Buys tickets for the current drawing. USDC is pulled from msg.sender via allowance.
    /// @param  _tickets Explicit number picks, one entry per ticket.
    /// @param  _recipient Address that receives the ticket NFTs.
    /// @param  _referrers Referrer addresses (may be empty). Non-zero, at most maxReferrers().
    /// @param  _referralSplit 1e18-scaled weights, same length as _referrers, summing to 1e18 when non-empty.
    /// @param  _source Free-form bytes32 telemetry tag.
    /// @return ticketIds Minted ticket NFT ids, one per entry of _tickets.
    function buyTickets(
        Ticket[] memory _tickets,
        address _recipient,
        address[] memory _referrers,
        uint256[] memory _referralSplit,
        bytes32 _source
    ) external returns (uint256[] memory ticketIds);

    /// @notice Burns the given tickets and pays out any winnings to msg.sender (0 for losing tickets).
    /// @dev    Reverts on an empty array or when any ticket belongs to a drawing that has not settled.
    function claimWinnings(uint256[] memory _userTicketIds) external;

    /// @notice Pays accrued referral fees to msg.sender. Reverts when nothing is claimable.
    function claimReferralFees() external;

    function currentDrawingId() external view returns (uint256);

    function ticketPrice() external view returns (uint256);

    function drawingDurationInSeconds() external view returns (uint256);

    function getDrawingState(uint256 _drawingId) external view returns (DrawingState memory);
}
