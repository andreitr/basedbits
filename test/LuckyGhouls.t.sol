// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {BBitsBurner} from "@src/BBitsBurner.sol";
import {LuckyGhouls, ILuckyGhouls, IV3Router, IV3Quoter, IJackpot} from "@src/LuckyGhouls.sol";
import {LuckyGhoulsArt} from "@src/modules/LuckyGhoulsArt.sol";
import {MockERC20} from "@test/mocks/MockERC20.sol";
import {MockWETH} from "@test/mocks/MockWETH.sol";
import {MockBurner} from "@test/mocks/MockBurner.sol";
import {MockV3Quoter} from "@test/mocks/MockV3Quoter.sol";
import {MockSwapRouterV2} from "@test/mocks/MockSwapRouterV2.sol";
import {MockJackpotV2} from "@test/mocks/MockJackpotV2.sol";

/// @dev forge test --match-contract LuckyGhoulsTest -vvv
///      Mock-based: no fork required. 1 ETH == 1000 USDC in the mocks, so N tickets cost N * 1e15 wei.
contract LuckyGhoulsTest is Test {
    LuckyGhouls public ghouls;
    LuckyGhoulsArt public artContract;
    MockWETH public weth;
    MockERC20 public usdcToken;
    MockBurner public mockBurner;
    MockV3Quoter public quoter;
    MockSwapRouterV2 public router;
    MockJackpotV2 public jackpot;

    address public owner;
    address public user0;
    address public user1;
    address public user2;

    uint256 public mintPrice = 0.0011 ether;
    uint256 constant USDC_PER_ETH = 1000e6;
    uint256 constant WEI_PER_TICKET = 1e15; // 1 USDC at the mock rate
    uint256 constant DRAWING = 163;

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        owner = address(0x69);
        user0 = address(0x100);
        user1 = address(0x200);
        user2 = address(0x300);
        vm.deal(owner, 10 ether);
        vm.deal(user0, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        weth = new MockWETH();
        usdcToken = new MockERC20("USD Coin", "USDC");
        mockBurner = new MockBurner();
        quoter = new MockV3Quoter(address(weth), USDC_PER_ETH);
        router = new MockSwapRouterV2(weth, usdcToken, USDC_PER_ETH);
        vm.deal(address(router), 100 ether);
        jackpot = new MockJackpotV2(usdcToken);
        artContract = new LuckyGhoulsArt();

        ghouls = new LuckyGhouls(
            owner,
            mintPrice,
            BBitsBurner(payable(address(mockBurner))),
            IERC20(address(weth)),
            IERC20(address(usdcToken)),
            IV3Router(address(router)),
            IV3Quoter(address(quoter)),
            IJackpot(address(jackpot)),
            artContract
        );
    }

    /// HELPERS ///

    /// @dev Gives the Cauldron exactly enough ETH for `n` tickets on the next ritual (single participation day)
    function _fundForTickets(uint256 n) internal {
        vm.prank(owner);
        ghouls.setRitualParticipationDays(1);
        vm.deal(address(ghouls), n * WEI_PER_TICKET);
    }

    function _mask(uint8[5] memory normals) internal pure returns (uint256 mask) {
        for (uint256 i = 0; i < 5; i++) {
            mask |= (1 << normals[i]);
        }
    }

    function _contains(uint8[5] memory normals, uint8 n) internal pure returns (bool) {
        for (uint256 i = 0; i < 5; i++) {
            if (normals[i] == n) return true;
        }
        return false;
    }

    function _assertValidTicket(ILuckyGhouls.PurchasedTicket memory t, uint8 ballMax, uint8 bonusballMax)
        internal
        pure
    {
        uint256 mask;
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(t.normals[i] >= 1 && t.normals[i] <= ballMax, "normal out of range");
            assertEq(mask & (1 << t.normals[i]), 0, "duplicate normal within ticket");
            mask |= (1 << t.normals[i]);
        }
        assertTrue(t.bonusball >= 1 && t.bonusball <= bonusballMax, "bonusball out of range");
    }

    /// CONSTRUCTOR ///

    function testConstructor() public view {
        assertEq(ghouls.name(), "Lucky Ghouls");
        assertEq(ghouls.symbol(), "GHOUL");
        assertEq(ghouls.owner(), owner);
        assertEq(address(ghouls.bbitsBurner()), address(mockBurner));
        assertEq(address(ghouls.weth()), address(weth));
        assertEq(address(ghouls.usdc()), address(usdcToken));
        assertEq(address(ghouls.uniswapRouter()), address(router));
        assertEq(address(ghouls.uniswapQuoter()), address(quoter));
        assertEq(address(ghouls.lottery()), address(jackpot));
        assertEq(address(ghouls.artContract()), address(artContract));
        assertEq(ghouls.MAX_SUPPLY(), 666);
        assertEq(ghouls.maxMint(), 50);
        assertEq(ghouls.totalSupply(), 0);
        assertEq(ghouls.circulatingSupply(), 0);
        assertEq(ghouls.mintPrice(), mintPrice);
        assertEq(ghouls.burnPercentage(), 2000);
        assertEq(ghouls.ritualParticipationDays(), 365);
        assertEq(ghouls.currentRitualDay(), 0);
        assertEq(ghouls.lastRitualDrawingId(), type(uint256).max);
        assertEq(ghouls.ritualGasReserve(), 600_000);
        assertEq(ghouls.RITUAL_SOURCE(), bytes32("LuckyGhouls"));
        assertEq(usdcToken.allowance(address(ghouls), address(jackpot)), type(uint256).max);
        assertEq(usdcToken.allowance(address(ghouls), address(router)), type(uint256).max);

        uint8[] memory evil = ghouls.getEvilNumbers();
        assertEq(evil.length, 4);
        assertEq(evil[0], 4);
        assertEq(evil[1], 9);
        assertEq(evil[2], 13);
        assertEq(evil[3], 17);
    }

    /// SUMMON ///

    function testSummon() public prank(user1) {
        ghouls.summon{value: mintPrice * 3}(3);

        assertEq(ghouls.totalSupply(), 3);
        assertEq(ghouls.circulatingSupply(), 3);
        assertEq(ghouls.ownerOf(0), user1);
        assertEq(ghouls.ownerOf(1), user1);
        assertEq(ghouls.ownerOf(2), user1);

        // 20% burned, 80% stays in the Cauldron
        assertEq(mockBurner.calls(), 1);
        assertEq(mockBurner.totalReceived(), (mintPrice * 3 * 2000) / 10_000);
        assertEq(mockBurner.lastMinAmountBurned(), 0);
        assertEq(address(ghouls).balance, mintPrice * 3 - mockBurner.totalReceived());
    }

    function testSummonSkipsBurnerWhenPercentageZero() public {
        vm.prank(owner);
        ghouls.setBurnPercentage(0);

        vm.prank(user1);
        ghouls.summon{value: mintPrice}(1);

        assertEq(mockBurner.calls(), 0);
        assertEq(address(ghouls).balance, mintPrice);
    }

    function testSummonFailureConditions() public prank(user1) {
        uint256 largeQuantity = ghouls.maxMint() + 1;
        vm.expectRevert(ILuckyGhouls.MaxMintPerCallExceeded.selector);
        ghouls.summon{value: mintPrice * largeQuantity}(largeQuantity);

        vm.expectRevert(ILuckyGhouls.InsufficientPayment.selector);
        ghouls.summon{value: mintPrice - 1}(1);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.summon{value: 0}(0);
    }

    function testSummonWhenPaused() public {
        vm.prank(owner);
        ghouls.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.summon{value: mintPrice}(1);
    }

    function testMaxSupply() public {
        uint256 max = ghouls.MAX_SUPPLY();
        uint256 perCall = ghouls.maxMint();
        vm.deal(user1, mintPrice * (max + 1));
        vm.startPrank(user1);
        uint256 fullBatches = max / perCall; // 13
        for (uint256 i = 0; i < fullBatches; i++) {
            ghouls.summon{value: mintPrice * perCall}(perCall);
        }
        uint256 remainder = max - fullBatches * perCall; // 16
        assertEq(remainder, 16);

        // One too many in the final batch
        vm.expectRevert(ILuckyGhouls.MaxSupplyReached.selector);
        ghouls.summon{value: mintPrice * (remainder + 1)}(remainder + 1);

        ghouls.summon{value: mintPrice * remainder}(remainder);
        assertEq(ghouls.totalSupply(), max);

        vm.expectRevert(ILuckyGhouls.MaxSupplyReached.selector);
        ghouls.summon{value: mintPrice}(1);
        vm.stopPrank();
    }

    /// BREAK THE PACT ///

    function testBreakThePact() public prank(user1) {
        ghouls.summon{value: mintPrice * 2}(2);
        vm.deal(address(ghouls), 1 ether);
        usdcToken.mint(address(ghouls), 100e6);

        uint256 ethBefore = user1.balance;

        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.PactBroken(0, user1, 0.5 ether, 50e6);
        ghouls.breakThePact(0);

        assertEq(ghouls.circulatingSupply(), 1);
        assertEq(ghouls.totalSupply(), 2);
        assertEq(user1.balance, ethBefore + 0.5 ether);
        assertEq(usdcToken.balanceOf(user1), 50e6);
        assertEq(address(ghouls).balance, 0.5 ether);
        assertEq(usdcToken.balanceOf(address(ghouls)), 50e6);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        ghouls.ownerOf(0);
    }

    function testBreakThePactFailureConditions() public {
        vm.prank(user1);
        ghouls.summon{value: mintPrice}(1);

        vm.prank(user2);
        vm.expectRevert(ILuckyGhouls.NotOwner.selector);
        ghouls.breakThePact(0);

        vm.deal(address(ghouls), 0);
        vm.prank(user1);
        vm.expectRevert(ILuckyGhouls.NoTreasuryAvailable.selector);
        ghouls.breakThePact(0);

        vm.prank(user1);
        ghouls.burn(0);
        assertEq(ghouls.circulatingSupply(), 0);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        ghouls.breakThePact(0);
    }

    function testBreakThePactWhenPaused() public {
        vm.prank(user1);
        ghouls.summon{value: mintPrice}(1);
        vm.deal(address(ghouls), 1 ether);

        vm.prank(owner);
        ghouls.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.breakThePact(0);
    }

    function testGetRedeemValue() public {
        (uint256 e, uint256 u) = ghouls.getRedeemValue();
        assertEq(e, 0);
        assertEq(u, 0);

        vm.prank(user1);
        ghouls.summon{value: mintPrice * 4}(4);
        vm.deal(address(ghouls), 2 ether);
        usdcToken.mint(address(ghouls), 10e6);

        (e, u) = ghouls.getRedeemValue();
        assertEq(e, 0.5 ether);
        assertEq(u, 2.5e6);
    }

    /// NIGHTLY RITUAL ///

    function testRitualFirstAttemptBuysFullTarget() public {
        _fundForTickets(12);

        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.NightlyRitualPerformed(1, DRAWING, 12, 12 * WEI_PER_TICKET);
        ghouls.performNightlyRitual();

        // One swap, twelve single-ticket purchases
        assertEq(router.ethToUsdcCalls(), 1);
        assertEq(jackpot.buyCalls(), 12);
        assertEq(jackpot.ticketsSold(), 12);
        assertEq(usdcToken.balanceOf(address(jackpot)), 12e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);

        // Guard + bookkeeping
        assertEq(ghouls.lastRitualDrawingId(), DRAWING);
        assertEq(ghouls.currentRitualDay(), 1);
        (uint256 count, uint256 drawingId, uint256 ts) = ghouls.ritualHistory(1);
        assertEq(count, 12);
        assertEq(drawingId, DRAWING);
        assertEq(ts, block.timestamp);
        (uint256 target, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(target, 12);
        assertEq(bought, 12);

        // Every ticket valid and pairwise distinct; ids recorded and owned by the Cauldron
        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        uint256[] memory ids = ghouls.heldTicketIds(DRAWING);
        assertEq(tickets.length, 12);
        assertEq(ids.length, 12);
        for (uint256 i = 0; i < tickets.length; i++) {
            _assertValidTicket(tickets[i], 30, 10);
            assertEq(ids[i], tickets[i].ticketId);
            (address recipient, uint256 soldDrawing,, uint8 soldBonus,) = jackpot.getSold(tickets[i].ticketId);
            assertEq(recipient, address(ghouls));
            assertEq(soldDrawing, DRAWING);
            assertEq(soldBonus, tickets[i].bonusball);
            assertEq(jackpot.getSoldSource(tickets[i].ticketId), bytes32("LuckyGhouls"));
            for (uint256 j = i + 1; j < tickets.length; j++) {
                bool same = _mask(tickets[i].normals) == _mask(tickets[j].normals)
                    && tickets[i].bonusball == tickets[j].bonusball;
                assertFalse(same, "duplicate ticket in drawing");
            }
        }

        // Second call for the same drawing is refused
        vm.expectRevert(ILuckyGhouls.RitualAlreadyPerformed.selector);
        ghouls.performNightlyRitual();
    }

    function testRitualEvilBias() public {
        _fundForTickets(3);
        ghouls.performNightlyRitual();

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        for (uint256 i = 0; i < tickets.length; i++) {
            assertTrue(_contains(tickets[i].normals, 4));
            assertTrue(_contains(tickets[i].normals, 9));
            assertTrue(_contains(tickets[i].normals, 13));
            assertTrue(_contains(tickets[i].normals, 17));
            assertEq(tickets[i].bonusball, 4);
        }
    }

    function testRitualSkipsEvilNumbersOutOfRange() public {
        jackpot.setRanges(10, 3);
        _fundForTickets(4);
        ghouls.performNightlyRitual();

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        assertEq(tickets.length, 4);
        for (uint256 i = 0; i < tickets.length; i++) {
            _assertValidTicket(tickets[i], 10, 3);
            assertTrue(_contains(tickets[i].normals, 4));
            assertTrue(_contains(tickets[i].normals, 9));
            assertFalse(_contains(tickets[i].normals, 13));
            assertFalse(_contains(tickets[i].normals, 17));
            // No evil number fits the bonusball range, so it falls back to a hashed pick
            assertTrue(tickets[i].bonusball >= 1 && tickets[i].bonusball <= 3);
        }
    }

    function testPreviewMatchesPurchase() public {
        (uint8[5] memory previewNormals, uint8 previewBonus, bool ok) = ghouls.previewEvilTicket(DRAWING, 0);
        assertTrue(ok);

        _fundForTickets(5);
        ghouls.performNightlyRitual();

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        assertEq(_mask(tickets[0].normals), _mask(previewNormals));
        assertEq(tickets[0].bonusball, previewBonus);

        // The next preview accounts for everything already bought
        (uint8[5] memory nextNormals, uint8 nextBonus, bool nextOk) = ghouls.previewEvilTicket(DRAWING, 5);
        assertTrue(nextOk);
        for (uint256 i = 0; i < tickets.length; i++) {
            bool same = _mask(tickets[i].normals) == _mask(nextNormals) && tickets[i].bonusball == nextBonus;
            assertFalse(same);
        }
    }

    function testRitualUsesReferrer() public {
        address referrer = address(0xBEEF);
        vm.prank(owner);
        ghouls.setRitualReferrer(referrer);
        _fundForTickets(2);
        ghouls.performNightlyRitual();

        (address[] memory referrers, uint256[] memory split) = jackpot.getSoldReferrers(1);
        assertEq(referrers.length, 1);
        assertEq(referrers[0], referrer);
        assertEq(split.length, 1);
        assertEq(split[0], 1e18);
    }

    function testRitualWithoutReferrer() public {
        _fundForTickets(1);
        ghouls.performNightlyRitual();
        (address[] memory referrers, uint256[] memory split) = jackpot.getSoldReferrers(1);
        assertEq(referrers.length, 0);
        assertEq(split.length, 0);
    }

    function testRitualSweepsUsdcDust() public {
        _fundForTickets(3);
        // Extra USDC sitting in the Cauldron gets swept back to ETH one 5-USDC chunk at a time
        usdcToken.mint(address(ghouls), 7e6);

        ghouls.performNightlyRitual();

        assertEq(router.usdcToEthCalls(), 1);
        assertEq(usdcToken.balanceOf(address(ghouls)), 2e6);
        assertEq(weth.balanceOf(address(ghouls)), 0, "WETH should be unwrapped");
        assertEq(address(ghouls).balance, (5e6 * 1e18) / USDC_PER_ETH);
    }

    function testRitualNoSweepBelowChunk() public {
        _fundForTickets(3);
        usdcToken.mint(address(ghouls), 4e6);
        ghouls.performNightlyRitual();
        assertEq(router.usdcToEthCalls(), 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 4e6);
    }

    function testRitualFailureConditions() public {
        // Nothing in the treasury
        vm.expectRevert(ILuckyGhouls.InsufficientTreasury.selector);
        ghouls.performNightlyRitual();

        // Budget too small for one whole ticket
        vm.prank(owner);
        ghouls.setRitualParticipationDays(1);
        vm.deal(address(ghouls), WEI_PER_TICKET / 2);
        vm.expectRevert(ILuckyGhouls.InsufficientUSDCForTicket.selector);
        ghouls.performNightlyRitual();

        // Paused
        vm.deal(address(ghouls), 3 * WEI_PER_TICKET);
        vm.prank(owner);
        ghouls.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.performNightlyRitual();
    }

    function testRitualPartialThenRetry() public {
        _fundForTickets(10);
        // Fourth purchase fails (ticket index 3)
        jackpot.setFailWhenSold(3);

        vm.expectEmit(true, false, false, false);
        emit ILuckyGhouls.TicketPurchaseFailed(DRAWING, 3, "");
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.NightlyRitualPartiallyPerformed(DRAWING, 3, 7);
        ghouls.performNightlyRitual();

        // Three secured, guard not satisfied, USDC for the rest still in the Cauldron
        (uint256 target, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(target, 10);
        assertEq(bought, 3);
        assertEq(ghouls.lastRitualDrawingId(), type(uint256).max);
        assertEq(ghouls.currentRitualDay(), 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 7e6);
        assertEq(router.ethToUsdcCalls(), 1);

        // Retry while the failure persists: nothing new is bought, still no revert
        ghouls.performNightlyRitual();
        (, bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 3);

        // Failure clears; retry does not re-swap, resumes at index 3, finishes
        jackpot.clearFail();
        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.NightlyRitualPerformed(1, DRAWING, 7, 0);
        ghouls.performNightlyRitual();

        assertEq(router.ethToUsdcCalls(), 1, "retry must not re-swap");
        assertEq(jackpot.buyCalls(), 10); // reverted calls roll back the mock's counter
        (target, bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 10);
        assertEq(ghouls.lastRitualDrawingId(), DRAWING);
        assertEq(ghouls.currentRitualDay(), 1);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        for (uint256 i = 0; i < tickets.length; i++) {
            for (uint256 j = i + 1; j < tickets.length; j++) {
                bool same = _mask(tickets[i].normals) == _mask(tickets[j].normals)
                    && tickets[i].bonusball == tickets[j].bonusball;
                assertFalse(same, "retry produced a duplicate");
            }
        }

        vm.expectRevert(ILuckyGhouls.RitualAlreadyPerformed.selector);
        ghouls.performNightlyRitual();
    }

    function testRitualFirstPurchaseFailsKeepsBudget() public {
        _fundForTickets(5);
        jackpot.setRevertAll(true);

        ghouls.performNightlyRitual(); // does not revert

        (uint256 target, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(target, 5);
        assertEq(bought, 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 5e6);
        assertEq(ghouls.currentRitualDay(), 0);

        jackpot.setRevertAll(false);
        ghouls.performNightlyRitual();
        (, bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 5);
        assertEq(ghouls.currentRitualDay(), 1);
    }

    function testRitualStopsAtGasReserve() public {
        _fundForTickets(8);
        vm.prank(owner);
        ghouls.setRitualGasReserve(30_000_000);

        // Reserve exceeds the whole call's gas: loop never starts, nothing reverts
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.NightlyRitualPartiallyPerformed(DRAWING, 0, 8);
        ghouls.performNightlyRitual{gas: 5_000_000}();

        (uint256 target, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(target, 8);
        assertEq(bought, 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 8e6);

        // Tight but reachable reserve: some progress, then a clean stop
        vm.prank(owner);
        ghouls.setRitualGasReserve(1_500_000);
        ghouls.performNightlyRitual{gas: 2_000_000}();
        (, bought) = ghouls.getRitualProgress(DRAWING);
        assertTrue(bought < 8, "should stop before the target");
        assertEq(ghouls.currentRitualDay(), 0);

        // Normal reserve finishes the job
        vm.prank(owner);
        ghouls.setRitualGasReserve(600_000);
        ghouls.performNightlyRitual();
        (, bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 8);
        assertEq(ghouls.currentRitualDay(), 1);
        assertEq(router.ethToUsdcCalls(), 1);
    }

    function testRitualExhaustionShrinksTarget() public {
        // Evil numbers fill four slots; ballMax 6 leaves only {5,6} for the fifth; one bonusball value.
        uint8[] memory evil = new uint8[](4);
        evil[0] = 1;
        evil[1] = 2;
        evil[2] = 3;
        evil[3] = 4;
        vm.prank(owner);
        ghouls.setEvilNumbers(evil);
        jackpot.setRanges(6, 1);
        _fundForTickets(10);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.EvilTicketSpaceExhausted(DRAWING, 2);
        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.NightlyRitualPerformed(1, DRAWING, 2, 10 * WEI_PER_TICKET);
        ghouls.performNightlyRitual();

        (uint256 target, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(target, 2);
        assertEq(bought, 2);
        assertEq(ghouls.lastRitualDrawingId(), DRAWING);
        (uint256 count,,) = ghouls.ritualHistory(1);
        assertEq(count, 2);
        // Unspent USDC: 8 left, one 5-chunk swept back
        assertEq(usdcToken.balanceOf(address(ghouls)), 3e6);
        assertEq(router.usdcToEthCalls(), 1);

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        assertTrue(_contains(tickets[0].normals, 5) != _contains(tickets[1].normals, 5));
        (,, bool ok) = ghouls.previewEvilTicket(DRAWING, 2);
        assertFalse(ok);
    }

    function testRitualUnreachableRangesFinalizeEmpty() public {
        jackpot.setRanges(4, 10); // fewer numbers than slots: nothing can be generated
        _fundForTickets(3);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.EvilTicketSpaceExhausted(DRAWING, 0);
        ghouls.performNightlyRitual();

        assertEq(jackpot.buyCalls(), 0);
        assertEq(ghouls.lastRitualDrawingId(), DRAWING);
        assertEq(usdcToken.balanceOf(address(ghouls)), 3e6);
    }

    function testRitualRollsOverToNextDrawing() public {
        vm.prank(owner);
        ghouls.setRitualParticipationDays(2);
        vm.deal(address(ghouls), 2 * 6 * WEI_PER_TICKET);

        ghouls.performNightlyRitual();
        assertEq(ghouls.currentRitualDay(), 1);
        (, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 6);

        jackpot.setCurrentDrawingId(DRAWING + 1);
        ghouls.performNightlyRitual();
        assertEq(ghouls.currentRitualDay(), 2);
        (, bought) = ghouls.getRitualProgress(DRAWING + 1);
        assertEq(bought, 6);
        (, uint256 drawingId,) = ghouls.ritualHistory(2);
        assertEq(drawingId, DRAWING + 1);
        assertEq(router.ethToUsdcCalls(), 2);
    }

    function testIncompleteRitualSurvivesRollover() public {
        _fundForTickets(4);
        jackpot.setFailWhenSold(2);
        ghouls.performNightlyRitual();
        (, uint256 bought) = ghouls.getRitualProgress(DRAWING);
        assertEq(bought, 2);

        // Drawing moves on before the retry: yesterday's two tickets stay claimable, today starts fresh
        jackpot.clearFail();
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.deal(address(ghouls), 3 * WEI_PER_TICKET);
        ghouls.performNightlyRitual();
        (, bought) = ghouls.getRitualProgress(DRAWING + 1);
        assertEq(bought, 3);
        assertEq(ghouls.heldTicketIds(DRAWING).length, 2);

        jackpot.setCurrentDrawingId(DRAWING + 2);
        ghouls.claimReckoning(DRAWING);
        assertEq(ghouls.heldTicketIds(DRAWING).length, 0);
    }

    /// CLAIM RECKONING ///

    function testClaimReckoning() public {
        _fundForTickets(4);
        ghouls.performNightlyRitual();
        uint256[] memory ids = ghouls.heldTicketIds(DRAWING);
        assertEq(ids.length, 4);

        // Not settled yet
        vm.expectRevert(ILuckyGhouls.DrawingNotSettled.selector);
        ghouls.claimReckoning(DRAWING);

        jackpot.setCurrentDrawingId(DRAWING + 1);
        jackpot.setPayoutPerTicket(2e6);
        usdcToken.mint(address(jackpot), 8e6);

        vm.prank(user2); // anyone can call
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.ReckoningClaimed(DRAWING, 4, 8e6);
        ghouls.claimReckoning(DRAWING);

        assertEq(usdcToken.balanceOf(address(ghouls)), 8e6);
        assertEq(ghouls.heldTicketIds(DRAWING).length, 0);
        assertEq(ghouls.getPurchasedTickets(DRAWING).length, 0);
        for (uint256 i = 0; i < ids.length; i++) {
            (,,,, bool burned) = jackpot.getSold(ids[i]);
            assertTrue(burned);
        }

        vm.expectRevert(ILuckyGhouls.NoTicketsForDrawing.selector);
        ghouls.claimReckoning(DRAWING);
    }

    function testClaimReckoningAllLosing() public {
        _fundForTickets(3);
        ghouls.performNightlyRitual();
        jackpot.setCurrentDrawingId(DRAWING + 1);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.ReckoningClaimed(DRAWING, 3, 0);
        ghouls.claimReckoning(DRAWING);
        assertEq(ghouls.heldTicketIds(DRAWING).length, 0);
    }

    function testClaimReckoningFailureConditions() public {
        vm.expectRevert(ILuckyGhouls.NoTicketsForDrawing.selector);
        ghouls.claimReckoning(DRAWING);

        _fundForTickets(1);
        ghouls.performNightlyRitual();
        jackpot.setCurrentDrawingId(DRAWING + 1);

        vm.prank(owner);
        ghouls.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.claimReckoning(DRAWING);
    }

    /// REFERRAL FEES ///

    function testClaimReferralFees() public {
        vm.expectRevert(MockJackpotV2.NoReferralFeesToClaim.selector);
        ghouls.claimReferralFees();

        usdcToken.mint(address(jackpot), 3e6);
        jackpot.setReferralFeesClaimable(3e6);
        ghouls.claimReferralFees();
        assertEq(usdcToken.balanceOf(address(ghouls)), 3e6);
    }

    /// SETTINGS ///

    function testSetSummoningPrice() public prank(owner) {
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.SummoningPriceUpdated(0.001 ether);
        ghouls.setSummoningPrice(0.001 ether);
        assertEq(ghouls.mintPrice(), 0.001 ether);
    }

    function testSetBurnPercentage() public prank(owner) {
        ghouls.setBurnPercentage(500);
        assertEq(ghouls.burnPercentage(), 500);

        vm.expectRevert(ILuckyGhouls.InvalidPercentage.selector);
        ghouls.setBurnPercentage(10001);
    }

    function testSetRitualParticipationDays() public prank(owner) {
        ghouls.setRitualParticipationDays(180);
        assertEq(ghouls.ritualParticipationDays(), 180);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setRitualParticipationDays(0);
    }

    function testSetRitualReferrer() public prank(owner) {
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.RitualReferrerUpdated(user2);
        ghouls.setRitualReferrer(user2);
        assertEq(ghouls.lotteryReferrer(), user2);
    }

    function testSetEvilNumbers() public prank(owner) {
        uint8[] memory evil = new uint8[](2);
        evil[0] = 6;
        evil[1] = 66;
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.EvilNumbersUpdated(evil);
        ghouls.setEvilNumbers(evil);
        uint8[] memory stored = ghouls.getEvilNumbers();
        assertEq(stored.length, 2);
        assertEq(stored[0], 6);
        assertEq(stored[1], 66);
        assertEq(ghouls.evilNumbers(1), 66);

        uint8[] memory empty = new uint8[](0);
        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setEvilNumbers(empty);

        evil[1] = 0;
        vm.expectRevert(ILuckyGhouls.InvalidEvilNumber.selector);
        ghouls.setEvilNumbers(evil);
    }

    function testSetRitualGasReserve() public prank(owner) {
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.RitualGasReserveUpdated(1_000_000);
        ghouls.setRitualGasReserve(1_000_000);
        assertEq(ghouls.ritualGasReserve(), 1_000_000);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setRitualGasReserve(0);
    }

    function testSettingsOnlyOwner() public prank(user1) {
        bytes memory err = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1);
        vm.expectRevert(err);
        ghouls.setSummoningPrice(1);
        vm.expectRevert(err);
        ghouls.setBurnPercentage(1);
        vm.expectRevert(err);
        ghouls.setRitualParticipationDays(1);
        vm.expectRevert(err);
        ghouls.setRitualReferrer(user1);
        vm.expectRevert(err);
        ghouls.setRitualGasReserve(1);
        vm.expectRevert(err);
        ghouls.setContractURI("x");
        vm.expectRevert(err);
        ghouls.pause();
        vm.expectRevert(err);
        ghouls.emergencyWithdraw(address(0));
        uint8[] memory evil = new uint8[](1);
        evil[0] = 1;
        vm.expectRevert(err);
        ghouls.setEvilNumbers(evil);
    }

    function testPauseUnpause() public prank(owner) {
        ghouls.pause();
        assertTrue(ghouls.paused());
        ghouls.unpause();
        assertFalse(ghouls.paused());
    }

    function testSetContractURI() public prank(owner) {
        assertEq(ghouls.contractURI(), "");
        ghouls.setContractURI("https://example.com/metadata.json");
        assertEq(ghouls.contractURI(), "https://example.com/metadata.json");
    }

    /// EMERGENCY WITHDRAW ///

    function testEmergencyWithdrawERC20() public prank(owner) {
        MockERC20 token = new MockERC20("Mock", "MCK");
        token.mint(address(ghouls), 500);
        ghouls.emergencyWithdraw(address(token));
        assertEq(token.balanceOf(owner), 500);
        assertEq(token.balanceOf(address(ghouls)), 0);
    }

    function testEmergencyWithdrawETH() public {
        vm.prank(owner);
        ghouls.transferOwnership(user1);
        vm.deal(address(ghouls), 2 ether);
        uint256 before = user1.balance;
        vm.prank(user1);
        ghouls.emergencyWithdraw(address(0));
        assertEq(user1.balance, before + 2 ether);
    }

    /// VIEWS / METADATA ///

    function testMegapotViews() public {
        jackpot.setPrizePool(123e6);
        jackpot.setDrawingTime(999_999);
        assertEq(ghouls.getCauldronJackpot(), 123e6);
        assertEq(ghouls.getNextDrawingTime(), 999_999);
        assertEq(ghouls.getDrawingDurationInSeconds(), 86_400);
    }

    function testGetDailyPurchaseAmount() public {
        assertEq(ghouls.getDailyPurchaseAmount(), 0);
        vm.deal(address(ghouls), 365 ether);
        assertEq(ghouls.getDailyPurchaseAmount(), 1 ether);
    }

    function testGetDailyPurchaseAmountAfterParticipationEnds() public {
        _fundForTickets(2);
        ghouls.performNightlyRitual();
        assertEq(ghouls.currentRitualDay(), 1);

        // Participation window used up: no budget, no underflow
        vm.deal(address(ghouls), 1 ether);
        assertEq(ghouls.getDailyPurchaseAmount(), 0);
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.expectRevert(ILuckyGhouls.InsufficientTreasury.selector);
        ghouls.performNightlyRitual();

        // Owner can extend the window and the ritual resumes
        vm.prank(owner);
        ghouls.setRitualParticipationDays(2);
        assertEq(ghouls.getDailyPurchaseAmount(), 1 ether);
    }

    function testTokenURI() public {
        vm.prank(user1);
        ghouls.summon{value: mintPrice}(1);
        string memory uri = ghouls.tokenURI(0);
        assertTrue(bytes(uri).length > 0);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999));
        ghouls.tokenURI(999);
    }

    function testOnERC721Received() public view {
        assertEq(ghouls.onERC721Received(address(0), address(0), 0, ""), LuckyGhouls.onERC721Received.selector);
    }
}
