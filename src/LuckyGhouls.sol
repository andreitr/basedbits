// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721Burnable, ERC721} from "@openzeppelin/token/ERC721/extensions/ERC721Burnable.sol";
import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {SafeERC20, IERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {BBitsBurner} from "@src/BBitsBurner.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IJackpot} from "@src/interfaces/megapot/IJackpot.sol";
import {ILuckyGhouls} from "@src/interfaces/ILuckyGhouls.sol";
import {LuckyGhoulsArt} from "@src/modules/LuckyGhoulsArt.sol";

/// @title  Lucky Ghouls
/// @notice ERC-721 collection whose mint proceeds pool into a shared treasury (the Cauldron). Every drawing a
///         keeper performs the Nightly Ritual: a slice of the Cauldron is swapped to USDC and spent on Megapot V2
///         tickets whose numbers are biased toward the configured Evil Numbers. Any holder may Break the Pact at
///         any time, burning their Ghoul for a proportional share of the ETH and USDC the Cauldron holds.
/// @dev    Structure mirrors PotRaider.sol; the ticket-purchase surface is rewritten for the Megapot V2 API
///         (discrete NFT tickets with explicit numbers, no built-in once-per-round guard, id-based claims).
contract LuckyGhouls is ILuckyGhouls, ERC721Burnable, Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable weth;

    IERC20 public immutable usdc;

    BBitsBurner public immutable bbitsBurner;

    /// @notice Uniswap V3 Router for ETH<->USDC swaps
    IV3Router public immutable uniswapRouter;

    /// @notice Uniswap V3 Quoter for swap estimation
    IV3Quoter public immutable uniswapQuoter;

    /// @notice Megapot V2 Jackpot
    IJackpot public immutable lottery;

    uint256 public immutable maxMint;

    LuckyGhoulsArt public immutable artContract;

    uint256 public constant MAX_SUPPLY = 666;

    uint256 public constant NORMALS_PER_TICKET = 5;

    /// @notice Upper bound on drawing-wide dedup retries per ticket before the generator gives up
    uint256 public constant MAX_GENERATOR_ATTEMPTS = 20;

    /// @notice Telemetry tag passed to Megapot on every purchase
    bytes32 public constant RITUAL_SOURCE = "LuckyGhouls";

    uint256 constant CHUNK_USDC = 5e6;

    /// @dev Megapot referral splits are scaled to 1e18
    uint256 constant PRECISE_UNIT = 1e18;

    /// @dev Bound on in-ticket re-rolls when filling the non-evil slots
    uint256 constant MAX_SLOT_REROLLS = 256;

    uint256 public totalSupply;

    uint256 public circulatingSupply;

    uint256 public mintPrice;

    /// @dev 10_000 = 100%
    uint256 public burnPercentage;

    /// @notice OpenSea-style contract-level metadata URI
    string public contractURI;

    /// @notice Referrer address for ticket purchases (zero = no referrer)
    address public lotteryReferrer;

    /// @notice Number of ritual days the treasury is spread across
    uint256 public ritualParticipationDays;

    /// @dev Internal counter of completed ritual days
    uint256 public currentRitualDay;

    /// @notice Megapot drawingId for which the ritual last reached its full ticket target
    /// @dev    Replaces the V1 usersInfo(address).active guard. Initialised to max so drawing 0 is not blocked.
    uint256 public lastRitualDrawingId;

    /// @notice Gas the ritual loop reserves before starting another purchase, so a long loop stops cleanly
    ///         instead of running out of gas and reverting its own earlier successes
    uint256 public ritualGasReserve;

    /// @notice Numbers the Evil Number Generator prefers, in priority order
    uint8[] public evilNumbers;

    /// @notice Tickets the ritual intends to buy for a drawing, locked in on the first attempt
    mapping(uint256 => uint256) public ritualTargetTicketCount;

    /// @dev Every ticket successfully bought per drawing (id + numbers), consumed by claimReckoning
    mapping(uint256 => PurchasedTicket[]) internal _purchasedTickets;

    /// @notice Per completed ritual day
    mapping(uint256 => RitualPurchase) public ritualHistory;

    constructor(
        address _owner,
        uint256 _mintPrice,
        BBitsBurner _bbitsBurner,
        IERC20 _weth,
        IERC20 _usdc,
        IV3Router _router,
        IV3Quoter _quoter,
        IJackpot _lottery,
        LuckyGhoulsArt _artContract
    ) ERC721("Lucky Ghouls", "GHOUL") Ownable(_owner) {
        mintPrice = _mintPrice;
        bbitsBurner = _bbitsBurner;
        weth = _weth;
        usdc = _usdc;
        uniswapRouter = _router;
        uniswapQuoter = _quoter;
        lottery = _lottery;
        artContract = _artContract;

        burnPercentage = 2000; // 20%
        maxMint = 50;
        ritualParticipationDays = 365;
        ritualGasReserve = 600_000;
        lastRitualDrawingId = type(uint256).max;

        evilNumbers.push(4);
        evilNumbers.push(9);
        evilNumbers.push(13);
        evilNumbers.push(17);

        usdc.approve(address(lottery), type(uint256).max);
        usdc.approve(address(uniswapRouter), type(uint256).max);
    }

    /// EXTERNAL ///

    receive() external payable {}

    /// @notice The Summoning: mint Ghouls for ETH. A burnPercentage share goes to the BBITS burner, the rest
    ///         stays in the Cauldron.
    function summon(uint256 quantity) external payable whenNotPaused nonReentrant {
        if (quantity == 0) revert QuantityZero();
        if (quantity > maxMint) revert MaxMintPerCallExceeded();
        if (totalSupply + quantity > MAX_SUPPLY) revert MaxSupplyReached();
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

    /// @notice Breaking the Pact: burn a Ghoul for its proportional share of the Cauldron's ETH and USDC.
    function breakThePact(uint256 tokenId) external whenNotPaused nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        // Calculate shares
        uint256 ethShare = address(this).balance / circulatingSupply;
        uint256 usdcShare = usdc.balanceOf(address(this)) / circulatingSupply;
        if (ethShare == 0 && usdcShare == 0) revert NoTreasuryAvailable();

        // Burn the NFT first (state update before external calls)
        burn(tokenId);

        // Send USDC share to the owner (if any)
        if (usdcShare > 0) usdc.safeTransfer(msg.sender, usdcShare);

        // Send ETH share to the owner
        (bool success,) = msg.sender.call{value: ethShare}("");
        if (!success) revert TransferFailed();

        emit PactBroken(tokenId, msg.sender, ethShare, usdcShare);
    }

    /// @notice Burns a token and updates circulating supply
    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        circulatingSupply--;
    }

    /// @notice The Nightly Ritual: buy this drawing's Megapot tickets, one at a time, until the day's target is
    ///         reached. Safe to call again for the same drawing after a partial run - a retry never re-swaps and
    ///         resumes from the first ticket not yet bought.
    /// @dev    Does not revert when a purchase fails or the gas reserve is hit; whatever was bought stays
    ///         committed and the once-per-drawing guard is only satisfied once the full target is reached.
    function performNightlyRitual() external whenNotPaused nonReentrant {
        uint256 currentId = lottery.currentDrawingId();
        if (lastRitualDrawingId == currentId) revert RitualAlreadyPerformed();

        // First attempt for this drawing: spend today's ETH budget and lock in the ticket target
        uint256 target = ritualTargetTicketCount[currentId];
        uint256 dailyAmount;
        if (target == 0) {
            dailyAmount = getDailyPurchaseAmount();
            if (dailyAmount == 0) revert InsufficientTreasury();

            uint256 usdcAmount = _swapETHForUSDC(dailyAmount);
            target = usdcAmount / lottery.ticketPrice();
            if (target == 0) revert InsufficientUSDCForTicket();

            ritualTargetTicketCount[currentId] = target;
        }

        PurchasedTicket[] storage tickets = _purchasedTickets[currentId];
        uint256 boughtThisCall;
        (address[] memory referrers, uint256[] memory referralSplit) = _referralArgs();

        for (uint256 ticketIndex = tickets.length; ticketIndex < target; ticketIndex++) {
            // Stop cleanly rather than running out of gas mid-purchase (which would revert this call entirely)
            if (gasleft() < ritualGasReserve) break;

            (uint8[5] memory normals, uint8 bonusball, bool ok) = _generateEvilTicket(currentId, ticketIndex);
            if (!ok) {
                // No further distinct combination is reachable: settle for what was secured so the ritual can
                // finalize instead of being stuck on this drawing forever
                emit EvilTicketSpaceExhausted(currentId, ticketIndex);
                ritualTargetTicketCount[currentId] = ticketIndex;
                target = ticketIndex;
                break;
            }

            IJackpot.Ticket[] memory order = new IJackpot.Ticket[](1);
            order[0] = IJackpot.Ticket({normals: _toDynamic(normals), bonusball: bonusball});

            try lottery.buyTickets(order, address(this), referrers, referralSplit, RITUAL_SOURCE) returns (
                uint256[] memory ticketIds
            ) {
                tickets.push(PurchasedTicket({ticketId: ticketIds[0], normals: normals, bonusball: bonusball}));
                boughtThisCall++;
            } catch (bytes memory reason) {
                emit TicketPurchaseFailed(currentId, ticketIndex, reason);
                break;
            }
        }

        if (tickets.length == target) {
            lastRitualDrawingId = currentId;
            currentRitualDay++;
            ritualHistory[currentRitualDay] =
                RitualPurchase({ticketCount: target, drawingId: currentId, timestamp: block.timestamp});

            // Swap leftover USDC dust back to ETH in 5 USDC increments
            if (usdc.balanceOf(address(this)) >= CHUNK_USDC) _swapUSDCforETH(CHUNK_USDC);

            emit NightlyRitualPerformed(currentRitualDay, currentId, boughtThisCall, dailyAmount);
        } else {
            emit NightlyRitualPartiallyPerformed(currentId, boughtThisCall, target - tickets.length);
        }
    }

    /// @notice The Reckoning: claim every ticket bought for a settled drawing (win or lose) in one call.
    /// @dev    Anyone can call this. Losing tickets simply pay 0; the drawing's records are cleared afterwards.
    function claimReckoning(uint256 drawingId) external whenNotPaused nonReentrant {
        PurchasedTicket[] storage tickets = _purchasedTickets[drawingId];
        uint256 count = tickets.length;
        if (count == 0) revert NoTicketsForDrawing();
        if (drawingId >= lottery.currentDrawingId()) revert DrawingNotSettled();

        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tickets[i].ticketId;
        }
        delete _purchasedTickets[drawingId];

        uint256 balanceBefore = usdc.balanceOf(address(this));
        lottery.claimWinnings(ids);
        uint256 usdcReceived = usdc.balanceOf(address(this)) - balanceBefore;

        emit ReckoningClaimed(drawingId, count, usdcReceived);
    }

    /// @notice Claim referral fees accrued on the Megapot contract
    /// @dev    Anyone can call this; reverts (in Megapot) when nothing is claimable
    function claimReferralFees() external whenNotPaused nonReentrant {
        lottery.claimReferralFees();
    }

    /// @notice Accept Megapot ticket NFTs (and any other ERC-721 safe-transferred to the Cauldron)
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
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

    /// @notice Set the number of ritual days the treasury is spread across
    function setRitualParticipationDays(uint256 _ritualParticipationDays) external onlyOwner {
        if (_ritualParticipationDays == 0) revert QuantityZero();
        ritualParticipationDays = _ritualParticipationDays;
        emit RitualParticipationDaysUpdated(_ritualParticipationDays);
    }

    /// @notice Set the referrer address used for ticket purchases (zero disables referrals)
    function setRitualReferrer(address _lotteryReferrer) external onlyOwner {
        lotteryReferrer = _lotteryReferrer;
        emit RitualReferrerUpdated(_lotteryReferrer);
    }

    function setSummoningPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit SummoningPriceUpdated(_mintPrice);
    }

    /// @notice Update the burn percentage
    /// @param _burnPercentage New burn percentage (10_000 = 100%)
    function setBurnPercentage(uint16 _burnPercentage) external onlyOwner {
        if (_burnPercentage > 10_000) revert InvalidPercentage();
        burnPercentage = _burnPercentage;
        emit BurnPercentageUpdated(_burnPercentage);
    }

    /// @notice Replace the Evil Numbers the generator is biased toward (priority order, all non-zero)
    function setEvilNumbers(uint8[] calldata _evilNumbers) external onlyOwner {
        if (_evilNumbers.length == 0) revert QuantityZero();
        for (uint256 i = 0; i < _evilNumbers.length; i++) {
            if (_evilNumbers[i] == 0) revert InvalidEvilNumber();
        }
        evilNumbers = _evilNumbers;
        emit EvilNumbersUpdated(_evilNumbers);
    }

    /// @notice Set the gas the ritual loop reserves before attempting another purchase
    function setRitualGasReserve(uint256 _ritualGasReserve) external onlyOwner {
        if (_ritualGasReserve == 0) revert QuantityZero();
        ritualGasReserve = _ritualGasReserve;
        emit RitualGasReserveUpdated(_ritualGasReserve);
    }

    /// INTERNAL ///

    /// @dev Referral arguments for buyTickets: empty when no referrer, else a single 100% split
    function _referralArgs() internal view returns (address[] memory referrers, uint256[] memory referralSplit) {
        if (lotteryReferrer == address(0)) {
            return (new address[](0), new uint256[](0));
        }
        referrers = new address[](1);
        referrers[0] = lotteryReferrer;
        referralSplit = new uint256[](1);
        referralSplit[0] = PRECISE_UNIT;
    }

    function _toDynamic(uint8[5] memory fixedNormals) internal pure returns (uint8[] memory normals) {
        normals = new uint8[](NORMALS_PER_TICKET);
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            normals[i] = fixedNormals[i];
        }
    }

    /// @notice Evil Number Generator: deterministic, biased toward evilNumbers, unique within the drawing.
    /// @dev    Reads ballMax/bonusballMax straight from Megapot for the drawing, fills as many normal slots as
    ///         possible with evil numbers (in configured order), hashes the rest, prefers the first evil number as
    ///         bonusball, and re-rolls (bumping `attempt`) until the combination differs from every ticket already
    ///         bought for the drawing. Returns ok=false once MAX_GENERATOR_ATTEMPTS is exhausted.
    function _generateEvilTicket(uint256 drawingId, uint256 ticketIndex)
        internal
        view
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        IJackpot.DrawingState memory ds = lottery.getDrawingState(drawingId);
        uint8 ballMax = ds.ballMax;
        uint8 bonusballMax = ds.bonusballMax;
        if (ballMax < NORMALS_PER_TICKET || bonusballMax == 0) return (normals, 0, false);

        PurchasedTicket[] storage existing = _purchasedTickets[drawingId];
        uint8[] memory evil = evilNumbers;

        for (uint256 attempt = 0; attempt < MAX_GENERATOR_ATTEMPTS; attempt++) {
            bool filled;
            (normals, filled) = _buildNormals(drawingId, ticketIndex, attempt, ballMax, evil);
            if (!filled) continue;
            bonusball = _pickBonusball(drawingId, ticketIndex, attempt, bonusballMax, evil);
            if (!_alreadyBought(existing, normals, bonusball)) return (normals, bonusball, true);
        }
        return (normals, bonusball, false);
    }

    /// @dev Evil numbers first (<= ballMax, no repeats), then hashed fill for the remaining slots
    function _buildNormals(uint256 drawingId, uint256 ticketIndex, uint256 attempt, uint8 ballMax, uint8[] memory evil)
        internal
        pure
        returns (uint8[5] memory normals, bool filled)
    {
        uint256 count;
        uint256 usedMask;

        for (uint256 i = 0; i < evil.length && count < NORMALS_PER_TICKET; i++) {
            uint8 n = evil[i];
            if (n == 0 || n > ballMax || (usedMask & _bit(n)) != 0) continue;
            normals[count++] = n;
            usedMask |= _bit(n);
        }

        uint256 nonce;
        while (count < NORMALS_PER_TICKET) {
            if (nonce >= MAX_SLOT_REROLLS) return (normals, false);
            uint8 candidate =
                uint8(1 + (uint256(keccak256(abi.encode(drawingId, ticketIndex, attempt, count, nonce))) % ballMax));
            nonce++;
            if ((usedMask & _bit(candidate)) != 0) continue;
            normals[count++] = candidate;
            usedMask |= _bit(candidate);
        }
        filled = true;
    }

    /// @dev First evil number within range, else a hashed fallback
    function _pickBonusball(
        uint256 drawingId,
        uint256 ticketIndex,
        uint256 attempt,
        uint8 bonusballMax,
        uint8[] memory evil
    ) internal pure returns (uint8) {
        for (uint256 i = 0; i < evil.length; i++) {
            if (evil[i] != 0 && evil[i] <= bonusballMax) return evil[i];
        }
        return uint8(1 + (uint256(keccak256(abi.encode(drawingId, ticketIndex, attempt, "bonus"))) % bonusballMax));
    }

    /// @dev Order-independent comparison against every ticket already bought for the drawing
    function _alreadyBought(PurchasedTicket[] storage existing, uint8[5] memory normals, uint8 bonusball)
        internal
        view
        returns (bool)
    {
        uint256 candidateMask = _normalsMask(normals);
        uint256 len = existing.length;
        for (uint256 i = 0; i < len; i++) {
            PurchasedTicket storage t = existing[i];
            if (t.bonusball == bonusball && _normalsMask(t.normals) == candidateMask) return true;
        }
        return false;
    }

    /// @dev Bit `n` of a normals bitmask (n <= 255)
    function _bit(uint8 n) internal pure returns (uint256) {
        return uint256(1) << n;
    }

    function _normalsMask(uint8[5] memory normals) internal pure returns (uint256 mask) {
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            mask |= _bit(normals[i]);
        }
    }

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
    function _estimateUSDCForETH(uint256 ethAmount) internal returns (uint256 estimatedUSDCAmount) {
        IV3Quoter.QuoteExactInputSingleParams memory params = IV3Quoter.QuoteExactInputSingleParams({
            tokenIn: address(weth), tokenOut: address(usdc), amountIn: ethAmount, fee: 500, sqrtPriceLimitX96: 0
        });
        (estimatedUSDCAmount,,,) = uniswapQuoter.quoteExactInputSingle(params);
    }

    /// @notice Internal function to estimate ETH output for a given USDC amount using Uniswap V3 Quoter
    function _estimateETHForUSDC(uint256 usdcAmount) internal returns (uint256 estimatedETHAmount) {
        IV3Quoter.QuoteExactInputSingleParams memory params = IV3Quoter.QuoteExactInputSingleParams({
            tokenIn: address(usdc), tokenOut: address(weth), amountIn: usdcAmount, fee: 500, sqrtPriceLimitX96: 0
        });
        (estimatedETHAmount,,,) = uniswapQuoter.quoteExactInputSingle(params);
    }

    /// VIEW ///

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return artContract.generateTokenURI(tokenId);
    }

    /// @notice Returns the ETH and USDC amounts redeemable per Ghoul
    function getRedeemValue() public view returns (uint256 ethShare, uint256 usdcShare) {
        if (circulatingSupply == 0) {
            return (0, 0);
        }
        ethShare = address(this).balance / circulatingSupply;
        usdcShare = usdc.balanceOf(address(this)) / circulatingSupply;
    }

    /// @notice Get the amount of ETH that will be spent on the next ritual's first attempt
    function getDailyPurchaseAmount() public view returns (uint256 ethPerDay) {
        if (currentRitualDay >= ritualParticipationDays) return 0;
        uint256 remainingDays = ritualParticipationDays - currentRitualDay;
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance == 0) return 0;
        ethPerDay = contractETHBalance / remainingDays;
    }

    /// @notice Current Megapot prize pool (USDC, 6 decimals)
    function getCauldronJackpot() external view returns (uint256 jackPot) {
        jackPot = lottery.getDrawingState(lottery.currentDrawingId()).prizePool;
    }

    /// @notice Timestamp at which the current drawing closes
    function getNextDrawingTime() external view returns (uint256 drawingTime) {
        drawingTime = lottery.getDrawingState(lottery.currentDrawingId()).drawingTime;
    }

    /// @notice Megapot drawing cycle length in seconds
    function getDrawingDurationInSeconds() external view returns (uint256 duration) {
        duration = lottery.drawingDurationInSeconds();
    }

    /// @notice Ticket NFT ids held for a drawing (empty once claimed)
    function heldTicketIds(uint256 drawingId) external view returns (uint256[] memory ids) {
        PurchasedTicket[] storage tickets = _purchasedTickets[drawingId];
        ids = new uint256[](tickets.length);
        for (uint256 i = 0; i < tickets.length; i++) {
            ids[i] = tickets[i].ticketId;
        }
    }

    /// @notice Full purchase records for a drawing
    function getPurchasedTickets(uint256 drawingId) external view returns (PurchasedTicket[] memory) {
        return _purchasedTickets[drawingId];
    }

    /// @notice Ritual progress for a drawing; a keeper should retry while bought < target
    function getRitualProgress(uint256 drawingId) external view returns (uint256 target, uint256 bought) {
        target = ritualTargetTicketCount[drawingId];
        bought = _purchasedTickets[drawingId].length;
    }

    function getEvilNumbers() external view returns (uint8[] memory) {
        return evilNumbers;
    }

    /// @notice Preview the ticket the generator would produce next for `ticketIndex`, given what is already bought
    function previewEvilTicket(uint256 drawingId, uint256 ticketIndex)
        external
        view
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        return _generateEvilTicket(drawingId, ticketIndex);
    }
}
