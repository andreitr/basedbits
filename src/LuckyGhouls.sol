// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
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
/// @notice ERC-721 collection whose mint proceeds pool into a shared treasury. Every drawing a keeper calls
///         `buyTickets`: a daily slice of the treasury is swapped to USDC and spent on Megapot V2 tickets whose
///         normals are drawn from the configured preferred-number pool in a low-overlap design and whose bonusball
///         rotates through Megapot's full bonusball range. Any holder may `burn` their token at any time for a
///         proportional share of the ETH and USDC the treasury holds.
/// @dev    Structure mirrors PotRaider.sol; the ticket-purchase surface is rewritten for the Megapot V2 API
///         (discrete NFT tickets with explicit numbers, no built-in once-per-round guard, id-based claims).
///         Winnings stay in the treasury as USDC and are only paid out through `burn`; they are never swapped
///         at claim time. One year after the first completed purchase, plus a 30-day grace period, the owner may
///         burn whatever is left in the treasury through the shared BBITS burner.
contract LuckyGhouls is ILuckyGhouls, ERC721, Ownable, Pausable, ReentrancyGuard, IERC721Receiver {
    using SafeERC20 for IERC20;

    IERC20 public immutable weth;

    IERC20 public immutable usdc;

    BBitsBurner public immutable bbitsBurner;

    /// @notice Uniswap V3 Router for ETH<->USDC swaps
    IV3Router public immutable uniswapRouter;

    /// @notice Uniswap V3 Quoter for swap estimation
    IV3Quoter public immutable uniswapQuoter;

    /// @notice Megapot V2 Jackpot
    IJackpot public immutable megapot;

    uint256 public immutable maxMintPerTx;

    LuckyGhoulsArt public immutable artContract;

    uint256 public constant MAX_SUPPLY = 666;

    uint256 public constant NORMALS_PER_TICKET = 5;

    /// @notice Upper bound on retries per ticket to find numbers not already bought for the drawing
    uint256 public constant MAX_UNIQUE_TICKET_ATTEMPTS = 20;

    /// @notice Telemetry tag passed to Megapot on every purchase
    bytes32 public constant MEGAPOT_SOURCE_TAG = "LuckyGhouls";

    /// @notice burnRemainingTreasury unlocks this long after the first completed purchase...
    uint256 public constant TREASURY_BURN_DELAY = 365 days;

    /// @notice ...plus this grace period, during which holders can still burn for their share
    uint256 public constant TREASURY_BURN_GRACE_PERIOD = 30 days;

    /// @dev Megapot referral splits are scaled to 1e18
    uint256 constant PRECISE_UNIT = 1e18;

    /// @notice Upper bound on the preferredNumbers pool size, bounding the per-ticket shuffle
    uint256 public constant MAX_PREFERRED_NUMBERS = 30;

    /// @dev Bound on in-ticket re-rolls when filling the non-preferred slots
    uint256 constant MAX_SLOT_REROLLS = 256;

    /// @dev Candidate tickets the design step scores before keeping the least-overlapping one
    uint256 constant DESIGN_CANDIDATES = 4;

    /// @dev Most recent tickets each design candidate is scored against, bounding per-ticket gas
    uint256 constant DESIGN_SCORE_WINDOW = 16;

    /// @dev Seed domains for the design candidates and the per-drawing bonusball offset
    uint256 constant DESIGN_DOMAIN = uint256(keccak256("LuckyGhouls.design"));
    uint256 constant BONUS_DOMAIN = uint256(keccak256("LuckyGhouls.bonus"));

    /// @dev Everything the ticket generator needs for one drawing, built once per buyTickets/preview call
    struct TicketContext {
        uint8 ballMax;
        uint8 bonusballMax;
        uint8[] pool; // preferred numbers in 1..ballMax
        uint256[] boughtMasks; // normals bitmask of every ticket bought for the drawing
        uint8[] boughtBonus;
        uint256 boughtCount;
    }

    uint256 public totalMinted;

    uint256 public totalSupply;

    uint256 public mintPrice;

    /// @dev 10_000 = 100%
    uint256 public mintBurnBps;

    /// @notice OpenSea-style contract-level metadata URI
    string public contractURI;

    /// @notice Megapot referral wallet credited on every ticket purchase (zero = no referrer)
    address public megapotReferrer;

    /// @notice Number of daily Megapot ticket purchases the treasury is spread across
    uint256 public totalPurchaseDays;

    /// @notice Number of days on which the full ticket target was bought
    uint256 public completedPurchaseDays;

    /// @notice Megapot drawingId for which buyTickets last reached its full ticket target
    /// @dev    Replaces the V1 usersInfo(address).active guard. Initialised to max so drawing 0 is not blocked.
    uint256 public lastCompletedDrawingId;

    /// @notice Gas buyTickets keeps in reserve before starting another purchase, so a long loop stops cleanly
    ///         instead of running out of gas and reverting its own earlier successes
    uint256 public minGasPerPurchase;

    /// @notice Timestamp of the first fully completed purchase; starts the treasury burn clock (0 = not started)
    uint256 public firstPurchaseTime;

    /// @notice Pool of numbers the ticket generator draws from (order irrelevant; out-of-range values are skipped)
    uint8[] public preferredNumbers;

    /// @notice Tickets buyTickets intends to buy for a drawing, locked in on the first attempt
    mapping(uint256 => uint256) public targetTicketCount;

    /// @notice USDC obtained from the day's ETH swap, per drawing (the day's whole ticket budget)
    mapping(uint256 => uint256) public drawingUsdcBudget;

    /// @notice Ticket price read on the day's first attempt, per drawing
    mapping(uint256 => uint256) public drawingTicketPrice;

    /// @dev Every ticket successfully bought per drawing (id + numbers), consumed by claimWinnings
    mapping(uint256 => PurchasedTicket[]) internal _purchasedTickets;

    /// @notice Purchase record per completed day number (1-based)
    mapping(uint256 => DailyPurchase) public purchaseHistoryByDay;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        uint256 _mintPrice,
        BBitsBurner _bbitsBurner,
        IERC20 _weth,
        IERC20 _usdc,
        IV3Router _router,
        IV3Quoter _quoter,
        IJackpot _megapot,
        LuckyGhoulsArt _artContract
    ) ERC721(_name, _symbol) Ownable(_owner) {
        mintPrice = _mintPrice;
        bbitsBurner = _bbitsBurner;
        weth = _weth;
        usdc = _usdc;
        uniswapRouter = _router;
        uniswapQuoter = _quoter;
        megapot = _megapot;
        artContract = _artContract;

        mintBurnBps = 2000; // 20%
        maxMintPerTx = 50;
        totalPurchaseDays = 365;
        minGasPerPurchase = 600_000;
        lastCompletedDrawingId = type(uint256).max;
        megapotReferrer = 0xDAdA5bAd8cdcB9e323d0606d081E6Dc5D3a577a1;

        // Default pool: numbers tied to death, the devil or bad luck across cultures
        preferredNumbers.push(4);
        preferredNumbers.push(6);
        preferredNumbers.push(7);
        preferredNumbers.push(9);
        preferredNumbers.push(13);
        preferredNumbers.push(14);
        preferredNumbers.push(15);
        preferredNumbers.push(16);
        preferredNumbers.push(17);
        preferredNumbers.push(24);

        usdc.approve(address(megapot), type(uint256).max);
        usdc.approve(address(uniswapRouter), type(uint256).max);
    }

    /// EXTERNAL ///

    receive() external payable {}

    /// @notice Mint tokens for ETH. A mintBurnBps share goes to the BBITS burner, the rest
    ///         stays in the treasury.
    function mint(uint256 quantity) external payable whenNotPaused nonReentrant {
        if (quantity == 0) revert QuantityZero();
        if (quantity > maxMintPerTx) revert MaxMintPerCallExceeded();
        if (totalMinted + quantity > MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value < mintPrice * quantity) revert InsufficientPayment();

        uint256 burnAmount = (msg.value * mintBurnBps) / 10_000;

        // Send burn amount to burner contract
        if (burnAmount > 0) bbitsBurner.burn{value: burnAmount}(0);

        for (uint256 i = 0; i < quantity; i++) {
            _mint(msg.sender, totalMinted);
            totalMinted++;
            totalSupply++;
        }
    }

    /// @notice Burn a token for its proportional share of the treasury's ETH and USDC.
    /// @dev    The only way to burn a Ghoul, so a burn always redeems its share.
    function burn(uint256 tokenId) external whenNotPaused nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        // Calculate shares
        uint256 ethShare = address(this).balance / totalSupply;
        uint256 usdcShare = usdc.balanceOf(address(this)) / totalSupply;
        if (ethShare == 0 && usdcShare == 0) revert NoTreasuryAvailable();

        // Burn the NFT first (state update before external calls)
        _burn(tokenId);
        totalSupply--;

        // Send USDC share to the owner (if any)
        if (usdcShare > 0) usdc.safeTransfer(msg.sender, usdcShare);

        // Send ETH share to the owner
        (bool success,) = msg.sender.call{value: ethShare}("");
        if (!success) revert TransferFailed();

        emit TokenBurned(tokenId, msg.sender, ethShare, usdcShare);
    }

    /// @notice Buy this drawing's Megapot tickets, one at a time, until the day's target is
    ///         reached. Callable by anyone while the drawing is open. Safe to call again for the same drawing after
    ///         a partial run - a retry never re-swaps and resumes from the first ticket not yet bought.
    /// @dev    Does not revert when a purchase fails or the gas reserve is hit; whatever was bought stays
    ///         committed and the once-per-drawing guard is only satisfied once the full target is reached.
    function buyTickets() external whenNotPaused nonReentrant {
        uint256 currentId = megapot.currentDrawingId();
        if (lastCompletedDrawingId == currentId) revert TicketsAlreadyPurchased();
        // While Megapot settles a drawing no ticket can be bought; refusing here keeps anyone from swapping the
        // day's budget into USDC that could never be spent on this drawing
        IJackpot.DrawingState memory ds = megapot.getDrawingState(currentId);
        if (ds.jackpotLock) revert DrawingLocked();

        // First attempt for this drawing: spend today's ETH budget and lock in the ticket target
        uint256 target = targetTicketCount[currentId];
        uint256 dailyAmount;
        if (target == 0) {
            dailyAmount = getDailyEthBudget();
            if (dailyAmount == 0) revert InsufficientTreasury();

            uint256 usdcAmount = _swapETHForUSDC(dailyAmount);
            uint256 price = megapot.ticketPrice();
            target = usdcAmount / price;
            if (target == 0) revert InsufficientUSDCForTicket();

            targetTicketCount[currentId] = target;
            drawingUsdcBudget[currentId] = usdcAmount;
            drawingTicketPrice[currentId] = price;
        }

        PurchasedTicket[] storage tickets = _purchasedTickets[currentId];
        uint256 boughtThisCall;
        (address[] memory referrers, uint256[] memory referralSplit) = _referralArgs();
        TicketContext memory ctx = _ticketContext(ds, currentId, target);

        for (uint256 ticketIndex = tickets.length; ticketIndex < target; ticketIndex++) {
            // Stop cleanly rather than running out of gas mid-purchase (which would revert this call entirely)
            if (gasleft() < minGasPerPurchase) break;

            (uint8[5] memory normals, uint8 bonusball, bool ok) = _generateTicket(ctx, currentId, ticketIndex);
            if (!ok) {
                // No further distinct combination is reachable: settle for what was secured so the day can
                // finalize instead of being stuck on this drawing forever
                emit UniqueTicketsExhausted(currentId, ticketIndex);
                targetTicketCount[currentId] = ticketIndex;
                target = ticketIndex;
                break;
            }

            IJackpot.Ticket[] memory order = new IJackpot.Ticket[](1);
            order[0] = IJackpot.Ticket({normals: _toDynamic(normals), bonusball: bonusball});

            try megapot.buyTickets(order, address(this), referrers, referralSplit, MEGAPOT_SOURCE_TAG) returns (
                uint256[] memory ticketIds
            ) {
                tickets.push(PurchasedTicket({ticketId: ticketIds[0], normals: normals, bonusball: bonusball}));
                ctx.boughtMasks[ctx.boughtCount] = _normalsMask(normals);
                ctx.boughtBonus[ctx.boughtCount++] = bonusball;
                boughtThisCall++;
            } catch (bytes memory reason) {
                emit TicketPurchaseFailed(currentId, ticketIndex, reason);
                break;
            }
        }

        if (tickets.length == target) {
            lastCompletedDrawingId = currentId;
            completedPurchaseDays++;
            purchaseHistoryByDay[completedPurchaseDays] =
                DailyPurchase({ticketCount: target, drawingId: currentId, timestamp: block.timestamp});

            // The first completed purchase starts the treasury burn clock
            if (firstPurchaseTime == 0) {
                firstPurchaseTime = block.timestamp;
                emit TreasuryBurnClockStarted(block.timestamp, getTreasuryBurnUnlockTime());
            }

            // Swap the day's own unspent budget back to ETH. Scoped to this day's remainder only - never the
            // contract's USDC balance, which may hold USDC earmarked for another drawing's pending tickets.
            uint256 leftover = drawingUsdcBudget[currentId] - tickets.length * drawingTicketPrice[currentId];
            uint256 usdcBalance = usdc.balanceOf(address(this));
            if (leftover > usdcBalance) leftover = usdcBalance;
            if (leftover > 0) _swapUSDCforETH(leftover);

            emit TicketsPurchased(completedPurchaseDays, currentId, boughtThisCall, dailyAmount);
        } else {
            emit TicketsPartiallyPurchased(currentId, boughtThisCall, target - tickets.length);
        }
    }

    /// @notice Claim every ticket bought for a settled drawing (win or lose) in one call. Any USDC won stays in
    ///         the treasury as USDC; holders collect their share by burning.
    /// @dev    Anyone can call this. Losing tickets simply pay 0; the drawing's records are cleared afterwards.
    ///         No swap happens here, so a large win cannot be sandwiched by whoever triggers the claim.
    function claimWinnings(uint256 drawingId) external whenNotPaused nonReentrant {
        PurchasedTicket[] storage tickets = _purchasedTickets[drawingId];
        uint256 count = tickets.length;
        if (count == 0) revert NoTicketsForDrawing();
        if (drawingId >= megapot.currentDrawingId()) revert DrawingNotSettled();

        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tickets[i].ticketId;
        }
        delete _purchasedTickets[drawingId];

        uint256 balanceBefore = usdc.balanceOf(address(this));
        megapot.claimWinnings(ids);
        uint256 usdcReceived = usdc.balanceOf(address(this)) - balanceBefore;

        emit WinningsClaimed(drawingId, count, usdcReceived);
    }

    /// @notice Accept Megapot ticket NFTs (and any other ERC-721 safe-transferred to this contract)
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /// SETTINGS ///

    /// @notice Once the grace period has closed, destroy whatever is left in the treasury by routing
    ///         it through the shared BBITS burner (USDC is converted to ETH first). Callable again if more
    ///         funds arrive later. Deliberately not gated by the pause switch.
    function burnRemainingTreasury() external onlyOwner nonReentrant {
        if (!isTreasuryBurnUnlocked()) revert TreasuryBurnLocked();

        uint256 usdcToBurn = usdc.balanceOf(address(this));
        if (usdcToBurn > 0) _swapUSDCforETH(usdcToBurn);

        uint256 ethToBurn = address(this).balance;
        if (ethToBurn == 0) revert NothingToBurn();

        bbitsBurner.burn{value: ethToBurn}(0);

        emit TreasuryBurned(ethToBurn, block.timestamp);
    }

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

    /// @notice Set the number of daily Megapot ticket purchases the treasury is spread across
    function setTotalPurchaseDays(uint256 _totalPurchaseDays) external onlyOwner {
        if (_totalPurchaseDays == 0) revert QuantityZero();
        totalPurchaseDays = _totalPurchaseDays;
        emit TotalPurchaseDaysUpdated(_totalPurchaseDays);
    }

    /// @notice Set the Megapot referral wallet used for ticket purchases (zero disables referrals)
    function setMegapotReferrer(address _megapotReferrer) external onlyOwner {
        megapotReferrer = _megapotReferrer;
        emit MegapotReferrerUpdated(_megapotReferrer);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    /// @notice Update the burn percentage
    /// @param _mintBurnBps Share of each mint sent to the BBITS burner (10_000 = 100%)
    function setMintBurnBps(uint16 _mintBurnBps) external onlyOwner {
        if (_mintBurnBps > 10_000) revert InvalidPercentage();
        mintBurnBps = _mintBurnBps;
        emit MintBurnBpsUpdated(_mintBurnBps);
    }

    /// @notice Replace the pool the ticket generator draws from: 5 to MAX_PREFERRED_NUMBERS distinct, non-zero
    ///         values. Values above the current ballMax are allowed and simply skipped until Megapot raises it.
    function setPreferredNumbers(uint8[] calldata _preferredNumbers) external onlyOwner {
        uint256 len = _preferredNumbers.length;
        if (len < NORMALS_PER_TICKET) revert TooFewPreferredNumbers();
        if (len > MAX_PREFERRED_NUMBERS) revert TooManyPreferredNumbers();
        uint256 usedMask;
        for (uint256 i = 0; i < len; i++) {
            uint8 n = _preferredNumbers[i];
            if (n == 0) revert InvalidPreferredNumber();
            if ((usedMask & _bit(n)) != 0) revert DuplicatePreferredNumber();
            usedMask |= _bit(n);
        }
        preferredNumbers = _preferredNumbers;
        emit PreferredNumbersUpdated(_preferredNumbers);
    }

    /// @notice Set the gas buyTickets keeps in reserve before attempting another purchase
    function setMinGasPerPurchase(uint256 _minGasPerPurchase) external onlyOwner {
        if (_minGasPerPurchase == 0) revert QuantityZero();
        minGasPerPurchase = _minGasPerPurchase;
        emit MinGasPerPurchaseUpdated(_minGasPerPurchase);
    }

    /// INTERNAL ///

    /// @dev Referral arguments for buyTickets: empty when no referrer, else a single 100% split
    function _referralArgs() internal view returns (address[] memory referrers, uint256[] memory referralSplit) {
        if (megapotReferrer == address(0)) {
            return (new address[](0), new uint256[](0));
        }
        referrers = new address[](1);
        referrers[0] = megapotReferrer;
        referralSplit = new uint256[](1);
        referralSplit[0] = PRECISE_UNIT;
    }

    function _toDynamic(uint8[5] memory fixedNormals) internal pure returns (uint8[] memory normals) {
        normals = new uint8[](NORMALS_PER_TICKET);
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            normals[i] = fixedNormals[i];
        }
    }

    /// @dev Takes ballMax/bonusballMax from the drawing state, filters the pool, and loads every ticket already
    ///      bought for the drawing into memory once. `capacity` reserves room for tickets recorded later in the
    ///      same call.
    function _ticketContext(IJackpot.DrawingState memory ds, uint256 drawingId, uint256 capacity)
        internal
        view
        returns (TicketContext memory ctx)
    {
        ctx.ballMax = ds.ballMax;
        ctx.bonusballMax = ds.bonusballMax;
        uint8[] memory preferred = preferredNumbers;
        ctx.pool = _eligible(preferred, ds.ballMax);

        PurchasedTicket[] storage existing = _purchasedTickets[drawingId];
        uint256 len = existing.length;
        if (capacity < len) capacity = len;
        ctx.boughtMasks = new uint256[](capacity);
        ctx.boughtBonus = new uint8[](capacity);
        for (uint256 i = 0; i < len; i++) {
            ctx.boughtMasks[i] = _normalsMask(existing[i].normals);
            ctx.boughtBonus[i] = existing[i].bonusball;
        }
        ctx.boughtCount = len;
    }

    /// @notice Ticket generator: deterministic, normals from the preferredNumbers pool, unique within the drawing.
    /// @dev    Bonusballs rotate through 1..bonusballMax from a per-drawing offset, so every bonusball value is
    ///         covered equally. With at least five pool numbers in range, normals come from `_designTicket`, which
    ///         keeps the drawing's tickets spread across the pool (low pairwise overlap, even number usage). If the
    ///         design step cannot produce an unbought ticket, up to MAX_UNIQUE_TICKET_ATTEMPTS seeded retries draw
    ///         five distinct pool numbers with a partial Fisher-Yates shuffle. With fewer than five in range (e.g.
    ///         Megapot lowered ballMax) the eligible ones are pinned and the other slots hashed. If every attempt
    ///         collides, a lexicographic sweep takes the first combination not yet bought, so ok=false means every
    ///         reachable combination is taken.
    function _generateTicket(TicketContext memory ctx, uint256 drawingId, uint256 ticketIndex)
        internal
        pure
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        if (ctx.ballMax < NORMALS_PER_TICKET || ctx.bonusballMax == 0) return (normals, 0, false);

        bool fromPool = ctx.pool.length >= NORMALS_PER_TICKET;
        if (fromPool) {
            (normals, bonusball, ok) = _designTicket(ctx, drawingId, ticketIndex);
            if (ok) return (normals, bonusball, true);
        }

        // One deck per ticket: re-shuffling an already shuffled deck keeps each draw uniform
        uint8[] memory deck;
        if (fromPool) deck = _copy(ctx.pool);

        for (uint256 attempt = 0; attempt < MAX_UNIQUE_TICKET_ATTEMPTS; attempt++) {
            bytes32 seed = keccak256(abi.encode(drawingId, ticketIndex, attempt));
            bool filled = true;
            if (fromPool) normals = _pickNormals(deck, seed);
            else (normals, filled) = _buildNormals(drawingId, ticketIndex, attempt, ctx.ballMax, ctx.pool);
            if (!filled) continue;
            bonusball = _rotatedBonusball(drawingId, ticketIndex + attempt, ctx.bonusballMax);
            if ((_usedBonusBits(ctx, _normalsMask(normals)) & _bit(bonusball)) == 0) {
                return (normals, bonusball, true);
            }
        }
        return _sweep(ctx);
    }

    /// @dev Low-overlap design for the drawing. Tickets come in pairs: an odd ticket avoids the numbers of the
    ///      ticket bought just before it as far as the pool allows (with a 10-number pool it is the exact
    ///      complement, so each pair uses every pool number once). Every ticket keeps the best of
    ///      DESIGN_CANDIDATES seeded candidates, scored by the sum of squared overlaps with the last
    ///      DESIGN_SCORE_WINDOW tickets bought for the drawing; ties go to the earliest candidate. ok=false when
    ///      every candidate is already bought with this ticket's bonusball.
    function _designTicket(TicketContext memory ctx, uint256 drawingId, uint256 ticketIndex)
        internal
        pure
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        bonusball = _rotatedBonusball(drawingId, ticketIndex, ctx.bonusballMax);

        uint256 avoidMask;
        if (ticketIndex % 2 == 1 && ticketIndex - 1 < ctx.boughtCount) avoidMask = ctx.boughtMasks[ticketIndex - 1];

        uint256 base = _hash(_hash(drawingId, ticketIndex), DESIGN_DOMAIN);
        uint256 bestScore = type(uint256).max;
        // Candidates are shuffled in place and hashed in scratch space: buyTickets generates many tickets in one
        // call and memory is never freed, so per-candidate allocations would grow gas quadratically
        uint8[] memory deck = _copy(ctx.pool);
        for (uint256 c = 0; c < DESIGN_CANDIDATES; c++) {
            _shuffleFront(deck, bytes32(_hash(base, c)), avoidMask);
            uint256 mask = _frontMask(deck);
            uint256 score = _overlapScore(ctx, mask);
            if (score >= bestScore) continue;
            if ((_usedBonusBits(ctx, mask) & _bit(bonusball)) != 0) continue;

            bestScore = score;
            for (uint256 j = 0; j < NORMALS_PER_TICKET; j++) {
                normals[j] = deck[j];
            }
            ok = true;
        }
    }

    /// @dev Sum of squared overlaps between `mask` and the last DESIGN_SCORE_WINDOW tickets bought
    function _overlapScore(TicketContext memory ctx, uint256 mask) internal pure returns (uint256 score) {
        uint256 count = ctx.boughtCount;
        uint256 start = count > DESIGN_SCORE_WINDOW ? count - DESIGN_SCORE_WINDOW : 0;
        uint256[] memory boughtMasks = ctx.boughtMasks;
        // boughtCount never exceeds boughtMasks.length, so the reads below stay in bounds
        for (uint256 i = start; i < count;) {
            uint256 bought;
            assembly ("memory-safe") {
                bought := mload(add(boughtMasks, shl(5, add(i, 1))))
            }
            unchecked {
                uint256 overlap = _popcount(mask & bought);
                score += overlap * overlap;
                i++;
            }
        }
    }

    /// @dev Normals bitmask of the five numbers at the front of `deck`
    function _frontMask(uint8[] memory deck) internal pure returns (uint256 mask) {
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            mask |= _bit(deck[i]);
        }
    }

    /// @dev Bonusball for `slot`: 1..bonusballMax in order, starting from a per-drawing offset
    function _rotatedBonusball(uint256 drawingId, uint256 slot, uint8 bonusballMax) internal pure returns (uint8) {
        uint256 offset = _hash(drawingId, BONUS_DOMAIN) % bonusballMax;
        return uint8(1 + ((offset + slot) % bonusballMax));
    }

    /// @dev keccak256(abi.encode(a, b)) without allocating memory
    function _hash(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    function _copy(uint8[] memory numbers) internal pure returns (uint8[] memory out) {
        out = new uint8[](numbers.length);
        for (uint256 i = 0; i < numbers.length; i++) {
            out[i] = numbers[i];
        }
    }

    /// @dev `numbers` filtered to 1..max, first occurrence of each value only
    function _eligible(uint8[] memory numbers, uint8 max) internal pure returns (uint8[] memory out) {
        out = new uint8[](numbers.length);
        uint256 count;
        uint256 usedMask;
        for (uint256 i = 0; i < numbers.length; i++) {
            uint8 n = numbers[i];
            if (n == 0 || n > max || (usedMask & _bit(n)) != 0) continue;
            out[count++] = n;
            usedMask |= _bit(n);
        }
        assembly ("memory-safe") {
            mstore(out, count)
        }
    }

    /// @dev Five distinct deck numbers via a seeded partial Fisher-Yates shuffle, in place (deck.length >= 5)
    function _pickNormals(uint8[] memory deck, bytes32 seed) internal pure returns (uint8[5] memory normals) {
        _shuffleFront(deck, seed, 0);
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            normals[i] = deck[i];
        }
    }

    /// @dev Seeded partial Fisher-Yates shuffle placing five distinct numbers at the front of `deck`. Numbers in
    ///      `avoidMask` are moved behind the rest first and only drawn once the rest run out.
    function _shuffleFront(uint8[] memory deck, bytes32 seed, uint256 avoidMask) internal pure {
        uint256 len = deck.length;
        uint256 preferredEnd = len;
        if (avoidMask != 0) {
            preferredEnd = 0;
            for (uint256 i = 0; i < len; i++) {
                if ((avoidMask & _bit(deck[i])) == 0) {
                    (deck[preferredEnd], deck[i]) = (deck[i], deck[preferredEnd]);
                    preferredEnd++;
                }
            }
        }
        for (uint256 i = 0; i < NORMALS_PER_TICKET; i++) {
            uint256 end = i < preferredEnd ? preferredEnd : len;
            uint256 j = i + (_hash(uint256(seed), i) % (end - i));
            (deck[i], deck[j]) = (deck[j], deck[i]);
        }
    }

    /// @dev Fallback when fewer than five pool numbers are in range: eligible pool numbers first, then hashed
    ///      fill for the remaining slots. `pool` is already filtered to 1..ballMax without repeats.
    function _buildNormals(uint256 drawingId, uint256 ticketIndex, uint256 attempt, uint8 ballMax, uint8[] memory pool)
        internal
        pure
        returns (uint8[5] memory normals, bool filled)
    {
        uint256 count;
        uint256 usedMask;

        for (uint256 i = 0; i < pool.length && count < NORMALS_PER_TICKET; i++) {
            normals[count++] = pool[i];
            usedMask |= _bit(pool[i]);
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

    /// @dev Walks every combination in lexicographic order - five pool numbers, or in the fallback the pinned
    ///      pool numbers plus the rest of 1..ballMax - and returns the first one with a free bonusball in
    ///      1..bonusballMax. ok=false means true exhaustion. Each full combination consumes at least one bought
    ///      ticket, so at most boughtCount + 1 are visited.
    function _sweep(TicketContext memory ctx)
        internal
        pure
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        uint8[] memory pinned;
        uint8[] memory others = ctx.pool;
        if (ctx.pool.length < NORMALS_PER_TICKET) {
            pinned = ctx.pool;
            others = _complement(ctx.pool, ctx.ballMax);
        }
        uint256 k = pinned.length;
        uint256 need = NORMALS_PER_TICKET - k;
        uint256 n = others.length;
        if (n < need) return (normals, 0, false);
        for (uint256 i = 0; i < k; i++) {
            normals[i] = pinned[i];
        }

        uint256[5] memory idx;
        for (uint256 i = 0; i < need; i++) {
            idx[i] = i;
        }

        while (true) {
            for (uint256 i = 0; i < need; i++) {
                normals[k + i] = others[idx[i]];
            }
            uint256 used = _usedBonusBits(ctx, _normalsMask(normals));
            for (uint256 b = 1; b <= ctx.bonusballMax; b++) {
                bonusball = uint8(b);
                if ((used & _bit(bonusball)) == 0) return (normals, bonusball, true);
            }

            // Advance to the next combination: bump the rightmost index that still has room
            uint256 j = need;
            while (j > 0 && idx[j - 1] == n - need + j - 1) {
                j--;
            }
            if (j == 0) return (normals, bonusball, false);
            idx[j - 1]++;
            for (uint256 m = j; m < need; m++) {
                idx[m] = idx[m - 1] + 1;
            }
        }
    }

    /// @dev 1..ballMax without the values in `pool`
    function _complement(uint8[] memory pool, uint8 ballMax) internal pure returns (uint8[] memory out) {
        uint256 poolMask;
        for (uint256 i = 0; i < pool.length; i++) {
            poolMask |= _bit(pool[i]);
        }
        out = new uint8[](ballMax);
        uint256 count;
        for (uint256 v = 1; v <= ballMax; v++) {
            if ((poolMask & _bit(uint8(v))) == 0) out[count++] = uint8(v);
        }
        assembly ("memory-safe") {
            mstore(out, count)
        }
    }

    /// @dev Bitmap of the bonusballs already bought with these normals (order-independent)
    function _usedBonusBits(TicketContext memory ctx, uint256 mask) internal pure returns (uint256 used) {
        for (uint256 i = 0; i < ctx.boughtCount; i++) {
            if (ctx.boughtMasks[i] == mask) used |= _bit(ctx.boughtBonus[i]);
        }
    }

    /// @dev Bit `n` of a normals bitmask (n <= 255)
    function _bit(uint8 n) internal pure returns (uint256) {
        return uint256(1) << n;
    }

    /// @dev Set bits in `x` (SWAR); the byte-sum fold is exact while the count stays below 256
    function _popcount(uint256 x) internal pure returns (uint256) {
        unchecked {
            x -= (x >> 1) & 0x5555555555555555555555555555555555555555555555555555555555555555;
            x = (x & 0x3333333333333333333333333333333333333333333333333333333333333333)
                + ((x >> 2) & 0x3333333333333333333333333333333333333333333333333333333333333333);
            x = (x + (x >> 4)) & 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
            return (x * 0x0101010101010101010101010101010101010101010101010101010101010101) >> 248;
        }
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
    function getBurnPayoutPerToken() public view returns (uint256 ethShare, uint256 usdcShare) {
        if (totalSupply == 0) {
            return (0, 0);
        }
        ethShare = address(this).balance / totalSupply;
        usdcShare = usdc.balanceOf(address(this)) / totalSupply;
    }

    /// @notice ETH the next day's first buyTickets call will swap and spend
    function getDailyEthBudget() public view returns (uint256 ethPerDay) {
        if (completedPurchaseDays >= totalPurchaseDays) return 0;
        uint256 remainingDays = totalPurchaseDays - completedPurchaseDays;
        uint256 contractETHBalance = address(this).balance;
        if (contractETHBalance == 0) return 0;
        ethPerDay = contractETHBalance / remainingDays;
    }

    /// @notice Current Megapot prize pool (USDC, 6 decimals)
    function getMegapotJackpot() external view returns (uint256 jackPot) {
        jackPot = megapot.getDrawingState(megapot.currentDrawingId()).prizePool;
    }

    /// @notice Timestamp at which the current drawing closes
    function getNextDrawingTime() external view returns (uint256 drawingTime) {
        drawingTime = megapot.getDrawingState(megapot.currentDrawingId()).drawingTime;
    }

    /// @notice Megapot drawing cycle length in seconds
    function getDrawingDurationInSeconds() external view returns (uint256 duration) {
        duration = megapot.drawingDurationInSeconds();
    }

    /// @notice Timestamp from which burnRemainingTreasury() may be called. type(uint256).max until the first
    ///         purchase has completed and started the clock.
    function getTreasuryBurnUnlockTime() public view returns (uint256) {
        if (firstPurchaseTime == 0) return type(uint256).max;
        return firstPurchaseTime + TREASURY_BURN_DELAY + TREASURY_BURN_GRACE_PERIOD;
    }

    /// @notice Whether the grace period has closed and the treasury may be burned
    function isTreasuryBurnUnlocked() public view returns (bool) {
        return block.timestamp >= getTreasuryBurnUnlockTime();
    }

    /// @notice Ticket NFT ids held for a drawing (empty once claimed)
    function getUnclaimedTicketIds(uint256 drawingId) external view returns (uint256[] memory ids) {
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

    /// @notice Ticket purchase progress for a drawing; a keeper should retry while bought < target
    function getPurchaseProgress(uint256 drawingId) external view returns (uint256 target, uint256 bought) {
        target = targetTicketCount[drawingId];
        bought = _purchasedTickets[drawingId].length;
    }

    function getPreferredNumbers() external view returns (uint8[] memory) {
        return preferredNumbers;
    }

    /// @notice Preview the ticket the generator would produce next for `ticketIndex`, given what is already bought
    function previewTicketNumbers(uint256 drawingId, uint256 ticketIndex)
        external
        view
        returns (uint8[5] memory normals, uint8 bonusball, bool ok)
    {
        return _generateTicket(_ticketContext(megapot.getDrawingState(drawingId), drawingId, 0), drawingId, ticketIndex);
    }
}
