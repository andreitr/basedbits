// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IJackpot} from "@src/interfaces/megapot/IJackpot.sol";
import {MockERC20} from "@test/mocks/MockERC20.sol";

/// @dev Behavioural mock of the Megapot V2 Jackpot: validates tickets like the real contract, pulls USDC,
///      issues sequential ticket ids, and reproduces the claim-path reverts. Winnings are paid from its own
///      USDC balance at `payoutPerTicket` per claimed ticket.
contract MockJackpotV2 is IJackpot {
    error InvalidTicketCount();
    error InvalidRecipient();
    error InvalidNormalsCount();
    error InvalidNormal();
    error DuplicateNormal();
    error InvalidBonusball();
    error ReferralSplitLengthMismatch();
    error ReferralSplitSumInvalid();
    error ZeroAddress();
    error NoTicketsToClaim();
    error NotTicketOwner();
    error TicketFromFutureDrawing();
    error NoReferralFeesToClaim();
    error MockPurchaseFailure();

    struct Sold {
        address recipient;
        uint256 drawingId;
        uint8[] normals;
        uint8 bonusball;
        bytes32 source;
        address[] referrers;
        uint256[] referralSplit;
        bool burned;
    }

    MockERC20 public usdc;

    uint256 public override currentDrawingId = 163;
    uint256 public override ticketPrice = 1e6;
    uint256 public override drawingDurationInSeconds = 86_400;
    uint8 public ballMax = 30;
    uint8 public bonusballMax = 10;
    uint256 public prizePool = 1_000_000e6;
    uint256 public drawingTime;
    mapping(uint256 => uint256) public winningTicket;

    uint256 public nextTicketId = 1;
    uint256 public buyCalls;
    uint256 public ticketsSold;
    bool public failArmed;
    uint256 public failWhenSold;
    bool public revertAll;
    uint256 public payoutPerTicket;
    uint256 public referralFeesClaimable;
    uint256 public claimCalls;

    mapping(uint256 => Sold) internal _sold;

    constructor(MockERC20 _usdc) {
        usdc = _usdc;
        drawingTime = block.timestamp + 1 days;
    }

    /// CONFIG ///

    function setCurrentDrawingId(uint256 _id) external {
        currentDrawingId = _id;
    }

    function setTicketPrice(uint256 _price) external {
        ticketPrice = _price;
    }

    function setRanges(uint8 _ballMax, uint8 _bonusballMax) external {
        ballMax = _ballMax;
        bonusballMax = _bonusballMax;
    }

    function setPrizePool(uint256 _prizePool) external {
        prizePool = _prizePool;
    }

    function setDrawingTime(uint256 _drawingTime) external {
        drawingTime = _drawingTime;
    }

    function setWinningTicket(uint256 _drawingId, uint256 _packed) external {
        winningTicket[_drawingId] = _packed;
    }

    /// @dev While armed, buyTickets reverts whenever `ticketsSold == n`, i.e. the purchase of ticket ordinal n+1
    ///      fails (and keeps failing on retry) until clearFail() is called. State written inside a reverting
    ///      call is rolled back, so the switch has to live in persisted state rather than a one-shot flag.
    function setFailWhenSold(uint256 n) external {
        failArmed = true;
        failWhenSold = n;
    }

    function clearFail() external {
        failArmed = false;
    }

    function setRevertAll(bool _revertAll) external {
        revertAll = _revertAll;
    }

    function setPayoutPerTicket(uint256 _payout) external {
        payoutPerTicket = _payout;
    }

    function setReferralFeesClaimable(uint256 _amount) external {
        referralFeesClaimable = _amount;
    }

    /// IJackpot ///

    function buyTickets(
        Ticket[] memory _tickets,
        address _recipient,
        address[] memory _referrers,
        uint256[] memory _referralSplit,
        bytes32 _source
    ) external override returns (uint256[] memory ticketIds) {
        buyCalls++;
        if (revertAll) revert MockPurchaseFailure();
        if (failArmed && ticketsSold == failWhenSold) revert MockPurchaseFailure();
        if (_tickets.length == 0) revert InvalidTicketCount();
        if (_recipient == address(0)) revert InvalidRecipient();
        if (_referrers.length != _referralSplit.length) revert ReferralSplitLengthMismatch();
        if (_referrers.length > 0) {
            uint256 sum;
            for (uint256 i = 0; i < _referrers.length; i++) {
                if (_referrers[i] == address(0)) revert ZeroAddress();
                sum += _referralSplit[i];
            }
            if (sum != 1e18) revert ReferralSplitSumInvalid();
        }

        require(usdc.transferFrom(msg.sender, address(this), _tickets.length * ticketPrice), "usdc pull failed");

        ticketIds = new uint256[](_tickets.length);
        for (uint256 i = 0; i < _tickets.length; i++) {
            Ticket memory t = _tickets[i];
            if (t.normals.length != 5) revert InvalidNormalsCount();
            if (t.bonusball == 0 || t.bonusball > bonusballMax) revert InvalidBonusball();
            uint256 mask;
            for (uint256 j = 0; j < 5; j++) {
                uint8 n = t.normals[j];
                if (n == 0 || n > ballMax) revert InvalidNormal();
                if ((mask & (1 << n)) != 0) revert DuplicateNormal();
                mask |= (1 << n);
            }

            uint256 id = nextTicketId++;
            Sold storage s = _sold[id];
            s.recipient = _recipient;
            s.drawingId = currentDrawingId;
            s.normals = t.normals;
            s.bonusball = t.bonusball;
            s.source = _source;
            s.referrers = _referrers;
            s.referralSplit = _referralSplit;
            ticketIds[i] = id;
            ticketsSold++;

            // Mirror a safe-mint so a contract recipient must accept ERC-721s
            if (_recipient.code.length > 0) {
                require(
                    IERC721Receiver(_recipient).onERC721Received(msg.sender, address(0), id, "")
                        == IERC721Receiver.onERC721Received.selector,
                    "unsafe recipient"
                );
            }
        }
    }

    function claimWinnings(uint256[] memory _userTicketIds) external override {
        claimCalls++;
        if (_userTicketIds.length == 0) revert NoTicketsToClaim();
        uint256 total;
        for (uint256 i = 0; i < _userTicketIds.length; i++) {
            Sold storage s = _sold[_userTicketIds[i]];
            if (s.recipient != msg.sender || s.burned) revert NotTicketOwner();
            if (s.drawingId >= currentDrawingId) revert TicketFromFutureDrawing();
            s.burned = true;
            total += payoutPerTicket;
        }
        require(usdc.transfer(msg.sender, total), "payout failed");
    }

    function claimReferralFees() external override {
        if (referralFeesClaimable == 0) revert NoReferralFeesToClaim();
        uint256 amount = referralFeesClaimable;
        referralFeesClaimable = 0;
        require(usdc.transfer(msg.sender, amount), "fee payout failed");
    }

    function getDrawingState(uint256 _drawingId) external view override returns (DrawingState memory ds) {
        ds.prizePool = prizePool;
        ds.ticketPrice = ticketPrice;
        ds.drawingTime = drawingTime;
        ds.winningTicket = winningTicket[_drawingId];
        ds.ballMax = ballMax;
        ds.bonusballMax = bonusballMax;
    }

    /// VIEW ///

    function getSold(uint256 id)
        external
        view
        returns (address recipient, uint256 drawingId, uint8[] memory normals, uint8 bonusball, bool burned)
    {
        Sold storage s = _sold[id];
        return (s.recipient, s.drawingId, s.normals, s.bonusball, s.burned);
    }

    function getSoldSource(uint256 id) external view returns (bytes32) {
        return _sold[id].source;
    }

    function getSoldReferrers(uint256 id) external view returns (address[] memory, uint256[] memory) {
        return (_sold[id].referrers, _sold[id].referralSplit);
    }
}
