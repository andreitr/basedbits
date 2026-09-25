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
        artContract = new LuckyGhoulsArt("Ghoul");

        ghouls = new LuckyGhouls(
            "Lucky Ghouls",
            "GHOUL",
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
        ghouls.setTotalPurchaseDays(1);
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
        assertEq(address(ghouls.megapot()), address(jackpot));
        assertEq(address(ghouls.artContract()), address(artContract));
        assertEq(ghouls.MAX_SUPPLY(), 666);
        assertEq(ghouls.maxMintPerTx(), 50);
        assertEq(ghouls.totalMinted(), 0);
        assertEq(ghouls.totalSupply(), 0);
        assertEq(ghouls.mintPrice(), mintPrice);
        assertEq(ghouls.mintBurnBps(), 2000);
        assertEq(ghouls.totalPurchaseDays(), 365);
        assertEq(ghouls.completedPurchaseDays(), 0);
        assertEq(ghouls.lastCompletedDrawingId(), type(uint256).max);
        assertEq(ghouls.minGasPerPurchase(), 600_000);
        assertEq(ghouls.MEGAPOT_SOURCE_TAG(), bytes32("LuckyGhouls"));
        assertEq(ghouls.TREASURY_BURN_DELAY(), 365 days);
        assertEq(ghouls.TREASURY_BURN_GRACE_PERIOD(), 30 days);
        assertEq(ghouls.firstPurchaseTime(), 0);
        assertEq(ghouls.getTreasuryBurnUnlockTime(), type(uint256).max);
        assertFalse(ghouls.isTreasuryBurnUnlocked());
        assertEq(usdcToken.allowance(address(ghouls), address(jackpot)), type(uint256).max);
        assertEq(usdcToken.allowance(address(ghouls), address(router)), type(uint256).max);

        uint8[] memory preferred = ghouls.getPreferredNumbers();
        assertEq(preferred.length, 4);
        assertEq(preferred[0], 4);
        assertEq(preferred[1], 9);
        assertEq(preferred[2], 13);
        assertEq(preferred[3], 17);
    }

    /// SUMMON ///

    function testMint() public prank(user1) {
        ghouls.mint{value: mintPrice * 3}(3);

        assertEq(ghouls.totalMinted(), 3);
        assertEq(ghouls.totalSupply(), 3);
        assertEq(ghouls.ownerOf(0), user1);
        assertEq(ghouls.ownerOf(1), user1);
        assertEq(ghouls.ownerOf(2), user1);

        // 20% burned, 80% stays in the Cauldron
        assertEq(mockBurner.calls(), 1);
        assertEq(mockBurner.totalReceived(), (mintPrice * 3 * 2000) / 10_000);
        assertEq(mockBurner.lastMinAmountBurned(), 0);
        assertEq(address(ghouls).balance, mintPrice * 3 - mockBurner.totalReceived());
    }

    function testMintSkipsBurnerWhenPercentageZero() public {
        vm.prank(owner);
        ghouls.setMintBurnBps(0);

        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);

        assertEq(mockBurner.calls(), 0);
        assertEq(address(ghouls).balance, mintPrice);
    }

    function testMintFailureConditions() public prank(user1) {
        uint256 largeQuantity = ghouls.maxMintPerTx() + 1;
        vm.expectRevert(ILuckyGhouls.MaxMintPerCallExceeded.selector);
        ghouls.mint{value: mintPrice * largeQuantity}(largeQuantity);

        vm.expectRevert(ILuckyGhouls.InsufficientPayment.selector);
        ghouls.mint{value: mintPrice - 1}(1);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.mint{value: 0}(0);
    }

    function testMintWhenPaused() public {
        vm.prank(owner);
        ghouls.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.mint{value: mintPrice}(1);
    }

    function testMaxSupply() public {
        uint256 max = ghouls.MAX_SUPPLY();
        uint256 perCall = ghouls.maxMintPerTx();
        vm.deal(user1, mintPrice * (max + 1));
        vm.startPrank(user1);
        uint256 fullBatches = max / perCall; // 13
        for (uint256 i = 0; i < fullBatches; i++) {
            ghouls.mint{value: mintPrice * perCall}(perCall);
        }
        uint256 remainder = max - fullBatches * perCall; // 16
        assertEq(remainder, 16);

        // One too many in the final batch
        vm.expectRevert(ILuckyGhouls.MaxSupplyReached.selector);
        ghouls.mint{value: mintPrice * (remainder + 1)}(remainder + 1);

        ghouls.mint{value: mintPrice * remainder}(remainder);
        assertEq(ghouls.totalMinted(), max);

        vm.expectRevert(ILuckyGhouls.MaxSupplyReached.selector);
        ghouls.mint{value: mintPrice}(1);
        vm.stopPrank();
    }

    /// BREAK THE PACT ///

    function testBurn() public prank(user1) {
        ghouls.mint{value: mintPrice * 2}(2);
        vm.deal(address(ghouls), 1 ether);
        usdcToken.mint(address(ghouls), 100e6);

        uint256 ethBefore = user1.balance;

        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.TokenBurned(0, user1, 0.5 ether, 50e6);
        ghouls.burn(0);

        assertEq(ghouls.totalSupply(), 1);
        assertEq(ghouls.totalMinted(), 2);
        assertEq(user1.balance, ethBefore + 0.5 ether);
        assertEq(usdcToken.balanceOf(user1), 50e6);
        assertEq(address(ghouls).balance, 0.5 ether);
        assertEq(usdcToken.balanceOf(address(ghouls)), 50e6);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        ghouls.ownerOf(0);
    }

    function testBurnFailureConditions() public {
        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);

        vm.prank(user2);
        vm.expectRevert(ILuckyGhouls.NotOwner.selector);
        ghouls.burn(0);

        vm.deal(address(ghouls), 0);
        vm.prank(user1);
        vm.expectRevert(ILuckyGhouls.NoTreasuryAvailable.selector);
        ghouls.burn(0);

        vm.deal(address(ghouls), 1 ether);
        vm.prank(user1);
        ghouls.burn(0);
        assertEq(ghouls.totalSupply(), 0);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        ghouls.burn(0);
    }

    function testBurnByApprovedOperatorReverts() public {
        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);
        vm.deal(address(ghouls), 1 ether);

        vm.prank(user1);
        ghouls.setApprovalForAll(user2, true);

        vm.prank(user2);
        vm.expectRevert(ILuckyGhouls.NotOwner.selector);
        ghouls.burn(0);
        assertEq(ghouls.ownerOf(0), user1);
    }

    function testBurnWhenPaused() public {
        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);
        vm.deal(address(ghouls), 1 ether);

        vm.prank(owner);
        ghouls.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.burn(0);
    }

    function testGetBurnPayoutPerToken() public {
        (uint256 e, uint256 u) = ghouls.getBurnPayoutPerToken();
        assertEq(e, 0);
        assertEq(u, 0);

        vm.prank(user1);
        ghouls.mint{value: mintPrice * 4}(4);
        vm.deal(address(ghouls), 2 ether);
        usdcToken.mint(address(ghouls), 10e6);

        (e, u) = ghouls.getBurnPayoutPerToken();
        assertEq(e, 0.5 ether);
        assertEq(u, 2.5e6);
    }

    /// NIGHTLY RITUAL ///

    function testBuyTicketsFirstAttemptBuysFullTarget() public {
        _fundForTickets(12);

        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.TicketsPurchased(1, DRAWING, 12, 12 * WEI_PER_TICKET);
        ghouls.buyTickets();

        // One swap, twelve single-ticket purchases
        assertEq(router.ethToUsdcCalls(), 1);
        assertEq(jackpot.buyCalls(), 12);
        assertEq(jackpot.ticketsSold(), 12);
        assertEq(usdcToken.balanceOf(address(jackpot)), 12e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);

        // Guard + bookkeeping
        assertEq(ghouls.lastCompletedDrawingId(), DRAWING);
        assertEq(ghouls.completedPurchaseDays(), 1);
        (uint256 count, uint256 drawingId, uint256 ts) = ghouls.purchaseHistoryByDay(1);
        assertEq(count, 12);
        assertEq(drawingId, DRAWING);
        assertEq(ts, vm.getBlockTimestamp());
        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 12);
        assertEq(bought, 12);
        assertEq(ghouls.drawingUsdcBudget(DRAWING), 12e6);
        assertEq(ghouls.drawingTicketPrice(DRAWING), 1e6);
        assertEq(router.usdcToEthCalls(), 0, "no remainder, nothing to sweep");
        assertEq(ghouls.firstPurchaseTime(), vm.getBlockTimestamp(), "first completed ritual starts the clock");
        assertEq(ghouls.getTreasuryBurnUnlockTime(), vm.getBlockTimestamp() + 395 days);

        // Every ticket valid and pairwise distinct; ids recorded and owned by the Cauldron
        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        uint256[] memory ids = ghouls.getUnclaimedTicketIds(DRAWING);
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
        vm.expectRevert(ILuckyGhouls.TicketsAlreadyPurchased.selector);
        ghouls.buyTickets();
    }

    function testBuyTicketsPreferredNumberBias() public {
        _fundForTickets(3);
        ghouls.buyTickets();

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        for (uint256 i = 0; i < tickets.length; i++) {
            assertTrue(_contains(tickets[i].normals, 4));
            assertTrue(_contains(tickets[i].normals, 9));
            assertTrue(_contains(tickets[i].normals, 13));
            assertTrue(_contains(tickets[i].normals, 17));
            assertEq(tickets[i].bonusball, 4);
        }
    }

    function testBuyTicketsSkipsPreferredNumbersOutOfRange() public {
        jackpot.setRanges(10, 3);
        _fundForTickets(4);
        ghouls.buyTickets();

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
        (uint8[5] memory previewNormals, uint8 previewBonus, bool ok) = ghouls.previewTicketNumbers(DRAWING, 0);
        assertTrue(ok);

        _fundForTickets(5);
        ghouls.buyTickets();

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        assertEq(_mask(tickets[0].normals), _mask(previewNormals));
        assertEq(tickets[0].bonusball, previewBonus);

        // The next preview accounts for everything already bought
        (uint8[5] memory nextNormals, uint8 nextBonus, bool nextOk) = ghouls.previewTicketNumbers(DRAWING, 5);
        assertTrue(nextOk);
        for (uint256 i = 0; i < tickets.length; i++) {
            bool same = _mask(tickets[i].normals) == _mask(nextNormals) && tickets[i].bonusball == nextBonus;
            assertFalse(same);
        }
    }

    function testBuyTicketsUsesReferrer() public {
        address referrer = address(0xBEEF);
        vm.prank(owner);
        ghouls.setMegapotReferrer(referrer);
        _fundForTickets(2);
        ghouls.buyTickets();

        (address[] memory referrers, uint256[] memory split) = jackpot.getSoldReferrers(1);
        assertEq(referrers.length, 1);
        assertEq(referrers[0], referrer);
        assertEq(split.length, 1);
        assertEq(split[0], 1e18);
    }

    function testBuyTicketsUsesDefaultReferrer() public {
        assertEq(ghouls.megapotReferrer(), 0xDAdA5bAd8cdcB9e323d0606d081E6Dc5D3a577a1);
        _fundForTickets(1);
        ghouls.buyTickets();

        (address[] memory referrers, uint256[] memory split) = jackpot.getSoldReferrers(1);
        assertEq(referrers.length, 1);
        assertEq(referrers[0], 0xDAdA5bAd8cdcB9e323d0606d081E6Dc5D3a577a1);
        assertEq(split[0], 1e18);
    }

    function testBuyTicketsWithoutReferrer() public {
        vm.prank(owner);
        ghouls.setMegapotReferrer(address(0));
        _fundForTickets(1);
        ghouls.buyTickets();
        (address[] memory referrers, uint256[] memory split) = jackpot.getSoldReferrers(1);
        assertEq(referrers.length, 0);
        assertEq(split.length, 0);
    }

    function testBuyTicketsSweepsDayRemainderOnly() public {
        // 3.5 USDC budget -> 3 tickets, 0.5 USDC of the day's own budget left over
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(1);
        vm.deal(address(ghouls), 3 * WEI_PER_TICKET + WEI_PER_TICKET / 2);
        // Unrelated USDC already in the Cauldron must not be touched
        usdcToken.mint(address(ghouls), 7e6);

        ghouls.buyTickets();

        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 3);
        assertEq(bought, 3);
        assertEq(router.usdcToEthCalls(), 1);
        assertEq(router.lastUsdcToEthAmount(), 0.5e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 7e6);
        assertEq(weth.balanceOf(address(ghouls)), 0, "WETH should be unwrapped");
        assertEq(address(ghouls).balance, (0.5e6 * 1e18) / USDC_PER_ETH);
    }

    function testBuyTicketsNoSweepWithoutRemainder() public {
        _fundForTickets(3);
        usdcToken.mint(address(ghouls), 7e6);
        ghouls.buyTickets();
        assertEq(router.usdcToEthCalls(), 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 7e6);
    }

    function testBuyTicketsRemainderSweptOnCompletionNotPartial() public {
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(1);
        vm.deal(address(ghouls), 4 * WEI_PER_TICKET + WEI_PER_TICKET / 4); // 4.25 USDC -> 4 tickets
        jackpot.setFailWhenSold(2);

        ghouls.buyTickets();
        assertEq(router.usdcToEthCalls(), 0, "partial run must not sweep");
        assertEq(usdcToken.balanceOf(address(ghouls)), 2.25e6);
        assertEq(ghouls.firstPurchaseTime(), 0, "partial run must not start the clock");

        jackpot.clearFail();
        ghouls.buyTickets();
        assertEq(router.usdcToEthCalls(), 1);
        assertEq(router.lastUsdcToEthAmount(), 0.25e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);
        assertEq(ghouls.firstPurchaseTime(), vm.getBlockTimestamp());
    }

    function testBuyTicketsFailureConditions() public {
        // Nothing in the treasury
        vm.expectRevert(ILuckyGhouls.InsufficientTreasury.selector);
        ghouls.buyTickets();

        // Budget too small for one whole ticket
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(1);
        vm.deal(address(ghouls), WEI_PER_TICKET / 2);
        vm.expectRevert(ILuckyGhouls.InsufficientUSDCForTicket.selector);
        ghouls.buyTickets();

        // Paused
        vm.deal(address(ghouls), 3 * WEI_PER_TICKET);
        vm.prank(owner);
        ghouls.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.buyTickets();
    }

    function testBuyTicketsPartialThenRetry() public {
        _fundForTickets(10);
        // Fourth purchase fails (ticket index 3)
        jackpot.setFailWhenSold(3);

        vm.expectEmit(true, false, false, false);
        emit ILuckyGhouls.TicketPurchaseFailed(DRAWING, 3, "");
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.TicketsPartiallyPurchased(DRAWING, 3, 7);
        ghouls.buyTickets();

        // Three secured, guard not satisfied, USDC for the rest still in the Cauldron
        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 10);
        assertEq(bought, 3);
        assertEq(ghouls.lastCompletedDrawingId(), type(uint256).max);
        assertEq(ghouls.completedPurchaseDays(), 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 7e6);
        assertEq(router.ethToUsdcCalls(), 1);

        // Retry while the failure persists: nothing new is bought, still no revert
        ghouls.buyTickets();
        (, bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 3);

        // Failure clears; retry does not re-swap, resumes at index 3, finishes
        jackpot.clearFail();
        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.TicketsPurchased(1, DRAWING, 7, 0);
        ghouls.buyTickets();

        assertEq(router.ethToUsdcCalls(), 1, "retry must not re-swap");
        assertEq(jackpot.buyCalls(), 10); // reverted calls roll back the mock's counter
        (target, bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 10);
        assertEq(ghouls.lastCompletedDrawingId(), DRAWING);
        assertEq(ghouls.completedPurchaseDays(), 1);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        for (uint256 i = 0; i < tickets.length; i++) {
            for (uint256 j = i + 1; j < tickets.length; j++) {
                bool same = _mask(tickets[i].normals) == _mask(tickets[j].normals)
                    && tickets[i].bonusball == tickets[j].bonusball;
                assertFalse(same, "retry produced a duplicate");
            }
        }

        vm.expectRevert(ILuckyGhouls.TicketsAlreadyPurchased.selector);
        ghouls.buyTickets();
    }

    function testBuyTicketsFirstPurchaseFailsKeepsBudget() public {
        _fundForTickets(5);
        jackpot.setRevertAll(true);

        ghouls.buyTickets(); // does not revert

        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 5);
        assertEq(bought, 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 5e6);
        assertEq(ghouls.completedPurchaseDays(), 0);

        jackpot.setRevertAll(false);
        ghouls.buyTickets();
        (, bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 5);
        assertEq(ghouls.completedPurchaseDays(), 1);
    }

    function testBuyTicketsStopsAtGasReserve() public {
        _fundForTickets(8);
        vm.prank(owner);
        ghouls.setMinGasPerPurchase(30_000_000);

        // Reserve exceeds the whole call's gas: loop never starts, nothing reverts
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.TicketsPartiallyPurchased(DRAWING, 0, 8);
        ghouls.buyTickets{gas: 5_000_000}();

        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 8);
        assertEq(bought, 0);
        assertEq(usdcToken.balanceOf(address(ghouls)), 8e6);

        // Tight but reachable reserve: some progress, then a clean stop
        vm.prank(owner);
        ghouls.setMinGasPerPurchase(1_500_000);
        ghouls.buyTickets{gas: 2_000_000}();
        (, bought) = ghouls.getPurchaseProgress(DRAWING);
        assertTrue(bought < 8, "should stop before the target");
        assertEq(ghouls.completedPurchaseDays(), 0);

        // Normal reserve finishes the job
        vm.prank(owner);
        ghouls.setMinGasPerPurchase(600_000);
        ghouls.buyTickets();
        (, bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 8);
        assertEq(ghouls.completedPurchaseDays(), 1);
        assertEq(router.ethToUsdcCalls(), 1);
    }

    function testBuyTicketsExhaustionShrinksTarget() public {
        // Evil numbers fill four slots; ballMax 6 leaves only {5,6} for the fifth; one bonusball value.
        uint8[] memory preferred = new uint8[](4);
        preferred[0] = 1;
        preferred[1] = 2;
        preferred[2] = 3;
        preferred[3] = 4;
        vm.prank(owner);
        ghouls.setPreferredNumbers(preferred);
        jackpot.setRanges(6, 1);
        _fundForTickets(10);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.UniqueTicketsExhausted(DRAWING, 2);
        vm.expectEmit(true, true, false, true);
        emit ILuckyGhouls.TicketsPurchased(1, DRAWING, 2, 10 * WEI_PER_TICKET);
        ghouls.buyTickets();

        (uint256 target, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(target, 2);
        assertEq(bought, 2);
        assertEq(ghouls.lastCompletedDrawingId(), DRAWING);
        (uint256 count,,) = ghouls.purchaseHistoryByDay(1);
        assertEq(count, 2);
        // The whole unspent budget (8 USDC) is swept back to ETH
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);
        assertEq(router.usdcToEthCalls(), 1);
        assertEq(router.lastUsdcToEthAmount(), 8e6);

        ILuckyGhouls.PurchasedTicket[] memory tickets = ghouls.getPurchasedTickets(DRAWING);
        assertTrue(_contains(tickets[0].normals, 5) != _contains(tickets[1].normals, 5));
        (,, bool ok) = ghouls.previewTicketNumbers(DRAWING, 2);
        assertFalse(ok);
    }

    function testBuyTicketsUnreachableRangesFinalizeEmpty() public {
        jackpot.setRanges(4, 10); // fewer numbers than slots: nothing can be generated
        _fundForTickets(3);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.UniqueTicketsExhausted(DRAWING, 0);
        ghouls.buyTickets();

        assertEq(jackpot.buyCalls(), 0);
        assertEq(ghouls.lastCompletedDrawingId(), DRAWING);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0, "unspent budget swept back to ETH");
        assertEq(router.lastUsdcToEthAmount(), 3e6);
    }

    function testBuyTicketsRollsOverToNextDrawing() public {
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(2);
        vm.deal(address(ghouls), 2 * 6 * WEI_PER_TICKET);

        ghouls.buyTickets();
        assertEq(ghouls.completedPurchaseDays(), 1);
        (, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 6);

        jackpot.setCurrentDrawingId(DRAWING + 1);
        ghouls.buyTickets();
        assertEq(ghouls.completedPurchaseDays(), 2);
        (, bought) = ghouls.getPurchaseProgress(DRAWING + 1);
        assertEq(bought, 6);
        (, uint256 drawingId,) = ghouls.purchaseHistoryByDay(2);
        assertEq(drawingId, DRAWING + 1);
        assertEq(router.ethToUsdcCalls(), 2);
    }

    function testIncompletePurchaseSurvivesRollover() public {
        _fundForTickets(4);
        jackpot.setFailWhenSold(2);
        ghouls.buyTickets();
        (, uint256 bought) = ghouls.getPurchaseProgress(DRAWING);
        assertEq(bought, 2);

        // Drawing moves on before the retry: yesterday's two tickets stay claimable, today starts fresh
        jackpot.clearFail();
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.deal(address(ghouls), 3 * WEI_PER_TICKET);
        ghouls.buyTickets();
        (, bought) = ghouls.getPurchaseProgress(DRAWING + 1);
        assertEq(bought, 3);
        assertEq(ghouls.getUnclaimedTicketIds(DRAWING).length, 2);
        assertEq(usdcToken.balanceOf(address(ghouls)), 2e6, "yesterday's earmarked USDC is not swept");
        assertEq(router.usdcToEthCalls(), 0);

        jackpot.setCurrentDrawingId(DRAWING + 2);
        ghouls.claimWinnings(DRAWING);
        assertEq(ghouls.getUnclaimedTicketIds(DRAWING).length, 0);
    }

    /// CLAIM RECKONING ///

    function testClaimWinnings() public {
        _fundForTickets(4);
        ghouls.buyTickets();
        uint256[] memory ids = ghouls.getUnclaimedTicketIds(DRAWING);
        assertEq(ids.length, 4);

        // Not settled yet
        vm.expectRevert(ILuckyGhouls.DrawingNotSettled.selector);
        ghouls.claimWinnings(DRAWING);

        jackpot.setCurrentDrawingId(DRAWING + 1);
        jackpot.setPayoutPerTicket(2e6);
        usdcToken.mint(address(jackpot), 8e6);

        uint256 ethBefore = address(ghouls).balance;
        vm.prank(user2); // anyone can call
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.WinningsClaimed(DRAWING, 4, 8e6, (8e6 * 1e18) / USDC_PER_ETH);
        ghouls.claimWinnings(DRAWING);

        // Winnings land in the Cauldron as ETH, not USDC
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);
        assertEq(address(ghouls).balance, ethBefore + (8e6 * 1e18) / USDC_PER_ETH);
        assertEq(router.usdcToEthCalls(), 1);
        assertEq(router.lastUsdcToEthAmount(), 8e6);
        assertEq(ghouls.getUnclaimedTicketIds(DRAWING).length, 0);
        assertEq(ghouls.getPurchasedTickets(DRAWING).length, 0);
        for (uint256 i = 0; i < ids.length; i++) {
            (,,,, bool burned) = jackpot.getSold(ids[i]);
            assertTrue(burned);
        }

        vm.expectRevert(ILuckyGhouls.NoTicketsForDrawing.selector);
        ghouls.claimWinnings(DRAWING);
    }

    function testClaimWinningsAllLosing() public {
        _fundForTickets(3);
        ghouls.buyTickets();
        jackpot.setCurrentDrawingId(DRAWING + 1);

        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.WinningsClaimed(DRAWING, 3, 0, 0);
        ghouls.claimWinnings(DRAWING);
        assertEq(ghouls.getUnclaimedTicketIds(DRAWING).length, 0);
        assertEq(router.usdcToEthCalls(), 0, "nothing to convert on a losing round");
    }

    function testClaimWinningsLeavesEarmarkedUsdcAlone() public {
        // Day 1 completes with 2 tickets
        _fundForTickets(2);
        ghouls.buyTickets();

        // Day 2 is only partially done: 2 of 4 bought, 2 USDC earmarked for the rest
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(2);
        vm.deal(address(ghouls), 4 * WEI_PER_TICKET);
        jackpot.setFailWhenSold(4); // 2 already sold on day 1; the 5th overall (day-2 index 2) fails
        ghouls.buyTickets();
        (, uint256 bought) = ghouls.getPurchaseProgress(DRAWING + 1);
        assertEq(bought, 2);
        assertEq(usdcToken.balanceOf(address(ghouls)), 2e6);

        // Claiming day 1's win converts exactly the winnings and nothing else
        jackpot.setPayoutPerTicket(3e6);
        usdcToken.mint(address(jackpot), 6e6);
        ghouls.claimWinnings(DRAWING);
        assertEq(router.lastUsdcToEthAmount(), 6e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 2e6, "earmarked USDC untouched");

        // The earmarked USDC still finishes day 2
        jackpot.clearFail();
        ghouls.buyTickets();
        (, bought) = ghouls.getPurchaseProgress(DRAWING + 1);
        assertEq(bought, 4);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);
    }

    function testClaimWinningsFailureConditions() public {
        vm.expectRevert(ILuckyGhouls.NoTicketsForDrawing.selector);
        ghouls.claimWinnings(DRAWING);

        _fundForTickets(1);
        ghouls.buyTickets();
        jackpot.setCurrentDrawingId(DRAWING + 1);

        vm.prank(owner);
        ghouls.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        ghouls.claimWinnings(DRAWING);
    }

    /// WIND-DOWN ///

    function testWindDownClockStartsAtFirstCompletedBuyTickets() public {
        // Before any ritual the burn is unreachable, however long we wait
        vm.warp(vm.getBlockTimestamp() + 3650 days);
        assertFalse(ghouls.isTreasuryBurnUnlocked());
        vm.prank(owner);
        vm.expectRevert(ILuckyGhouls.TreasuryBurnLocked.selector);
        ghouls.burnRemainingTreasury();

        // A partial ritual does not start the clock
        _fundForTickets(3);
        jackpot.setRevertAll(true);
        ghouls.buyTickets();
        assertEq(ghouls.firstPurchaseTime(), 0);

        // The first completed ritual does
        jackpot.setRevertAll(false);
        uint256 t0 = vm.getBlockTimestamp();
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.TreasuryBurnClockStarted(t0, t0 + 395 days);
        ghouls.buyTickets();
        assertEq(ghouls.firstPurchaseTime(), t0);
        assertEq(ghouls.getTreasuryBurnUnlockTime(), t0 + 395 days);

        // A later completed ritual does not move it
        vm.warp(t0 + 1 days);
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(2);
        vm.deal(address(ghouls), 2 * WEI_PER_TICKET);
        ghouls.buyTickets();
        assertEq(ghouls.completedPurchaseDays(), 2);
        assertEq(ghouls.firstPurchaseTime(), t0);
    }

    function _startWindDownClock() internal returns (uint256 unlockTime) {
        _fundForTickets(2);
        ghouls.buyTickets();
        unlockTime = ghouls.getTreasuryBurnUnlockTime();
        assertEq(unlockTime, vm.getBlockTimestamp() + 395 days);
    }

    function testBurnRemainingTreasury() public {
        uint256 unlockTime = _startWindDownClock();
        vm.deal(address(ghouls), 1 ether);
        usdcToken.mint(address(ghouls), 10e6);
        uint256 burnerBefore = mockBurner.totalReceived();

        // One second early: still locked
        vm.warp(unlockTime - 1);
        assertFalse(ghouls.isTreasuryBurnUnlocked());
        vm.prank(owner);
        vm.expectRevert(ILuckyGhouls.TreasuryBurnLocked.selector);
        ghouls.burnRemainingTreasury();

        // At the unlock time: USDC converted first, then everything burned through BBitsBurner
        vm.warp(unlockTime);
        assertTrue(ghouls.isTreasuryBurnUnlocked());
        uint256 expectedEth = 1 ether + (10e6 * 1e18) / USDC_PER_ETH;
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.TreasuryBurned(expectedEth, unlockTime);
        ghouls.burnRemainingTreasury();

        assertEq(router.lastUsdcToEthAmount(), 10e6);
        assertEq(usdcToken.balanceOf(address(ghouls)), 0);
        assertEq(address(ghouls).balance, 0);
        assertEq(mockBurner.totalReceived() - burnerBefore, expectedEth);
        assertEq(mockBurner.lastMinAmountBurned(), 0);
    }

    function testBurnRemainingTreasuryFailureConditionsAndRepeat() public {
        uint256 unlockTime = _startWindDownClock();
        vm.warp(unlockTime);

        // Only the owner
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        ghouls.burnRemainingTreasury();

        // Nothing there
        vm.deal(address(ghouls), 0);
        vm.prank(owner);
        vm.expectRevert(ILuckyGhouls.NothingToBurn.selector);
        ghouls.burnRemainingTreasury();

        // Works while paused
        vm.startPrank(owner);
        ghouls.pause();
        vm.deal(address(ghouls), 1 ether);
        ghouls.burnRemainingTreasury();
        assertEq(address(ghouls).balance, 0);

        // Callable again once more funds arrive
        vm.deal(address(ghouls), 0.5 ether);
        ghouls.burnRemainingTreasury();
        assertEq(address(ghouls).balance, 0);
        vm.stopPrank();
    }

    function testBurnAfterBurnReverts() public {
        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);
        uint256 unlockTime = _startWindDownClock();
        vm.deal(address(ghouls), 1 ether);
        vm.warp(unlockTime);
        vm.prank(owner);
        ghouls.burnRemainingTreasury();

        vm.prank(user1);
        vm.expectRevert(ILuckyGhouls.NoTreasuryAvailable.selector);
        ghouls.burn(0);
    }

    /// SETTINGS ///

    function testSetMintPrice() public prank(owner) {
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.MintPriceUpdated(0.001 ether);
        ghouls.setMintPrice(0.001 ether);
        assertEq(ghouls.mintPrice(), 0.001 ether);
    }

    function testSetMintBurnBps() public prank(owner) {
        ghouls.setMintBurnBps(500);
        assertEq(ghouls.mintBurnBps(), 500);

        vm.expectRevert(ILuckyGhouls.InvalidPercentage.selector);
        ghouls.setMintBurnBps(10001);
    }

    function testSetTotalPurchaseDays() public prank(owner) {
        ghouls.setTotalPurchaseDays(180);
        assertEq(ghouls.totalPurchaseDays(), 180);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setTotalPurchaseDays(0);
    }

    function testSetMegapotReferrer() public prank(owner) {
        vm.expectEmit(true, false, false, true);
        emit ILuckyGhouls.MegapotReferrerUpdated(user2);
        ghouls.setMegapotReferrer(user2);
        assertEq(ghouls.megapotReferrer(), user2);
    }

    function testSetPreferredNumbers() public prank(owner) {
        uint8[] memory preferred = new uint8[](2);
        preferred[0] = 6;
        preferred[1] = 66;
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.PreferredNumbersUpdated(preferred);
        ghouls.setPreferredNumbers(preferred);
        uint8[] memory stored = ghouls.getPreferredNumbers();
        assertEq(stored.length, 2);
        assertEq(stored[0], 6);
        assertEq(stored[1], 66);
        assertEq(ghouls.preferredNumbers(1), 66);

        uint8[] memory empty = new uint8[](0);
        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setPreferredNumbers(empty);

        preferred[1] = 0;
        vm.expectRevert(ILuckyGhouls.InvalidPreferredNumber.selector);
        ghouls.setPreferredNumbers(preferred);
    }

    function testSetMinGasPerPurchase() public prank(owner) {
        vm.expectEmit(false, false, false, true);
        emit ILuckyGhouls.MinGasPerPurchaseUpdated(1_000_000);
        ghouls.setMinGasPerPurchase(1_000_000);
        assertEq(ghouls.minGasPerPurchase(), 1_000_000);

        vm.expectRevert(ILuckyGhouls.QuantityZero.selector);
        ghouls.setMinGasPerPurchase(0);
    }

    function testSettingsOnlyOwner() public prank(user1) {
        bytes memory err = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1);
        vm.expectRevert(err);
        ghouls.setMintPrice(1);
        vm.expectRevert(err);
        ghouls.setMintBurnBps(1);
        vm.expectRevert(err);
        ghouls.setTotalPurchaseDays(1);
        vm.expectRevert(err);
        ghouls.setMegapotReferrer(user1);
        vm.expectRevert(err);
        ghouls.setMinGasPerPurchase(1);
        vm.expectRevert(err);
        ghouls.setContractURI("x");
        vm.expectRevert(err);
        ghouls.pause();
        vm.expectRevert(err);
        ghouls.emergencyWithdraw(address(0));
        vm.expectRevert(err);
        ghouls.burnRemainingTreasury();
        uint8[] memory preferred = new uint8[](1);
        preferred[0] = 1;
        vm.expectRevert(err);
        ghouls.setPreferredNumbers(preferred);
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
        assertEq(ghouls.getMegapotJackpot(), 123e6);
        assertEq(ghouls.getNextDrawingTime(), 999_999);
        assertEq(ghouls.getDrawingDurationInSeconds(), 86_400);
    }

    function testGetDailyEthBudget() public {
        assertEq(ghouls.getDailyEthBudget(), 0);
        vm.deal(address(ghouls), 365 ether);
        assertEq(ghouls.getDailyEthBudget(), 1 ether);
    }

    function testGetDailyEthBudgetAfterParticipationEnds() public {
        _fundForTickets(2);
        ghouls.buyTickets();
        assertEq(ghouls.completedPurchaseDays(), 1);

        // Participation window used up: no budget, no underflow
        vm.deal(address(ghouls), 1 ether);
        assertEq(ghouls.getDailyEthBudget(), 0);
        jackpot.setCurrentDrawingId(DRAWING + 1);
        vm.expectRevert(ILuckyGhouls.InsufficientTreasury.selector);
        ghouls.buyTickets();

        // Owner can extend the window and the ritual resumes
        vm.prank(owner);
        ghouls.setTotalPurchaseDays(2);
        assertEq(ghouls.getDailyEthBudget(), 1 ether);
    }

    function testTokenURI() public {
        vm.prank(user1);
        ghouls.mint{value: mintPrice}(1);
        string memory uri = ghouls.tokenURI(0);
        assertTrue(bytes(uri).length > 0);

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999));
        ghouls.tokenURI(999);
    }

    function testArtIsStaticAcrossTokens() public view {
        assertEq(artContract.tokenNamePrefix(), "Ghoul");
        string memory a = artContract.generateSVG(0);
        string memory b = artContract.generateSVG(665);
        assertEq(keccak256(bytes(a)), keccak256(bytes(b)), "art must not vary per token");
        assertTrue(bytes(a).length > 100);
        // Background from luckyghoul.svg is kept as-is
        assertTrue(_contains(a, '<rect width="48" height="48" fill="#EA9412"/>'));
        assertTrue(_startsWith(a, "<svg "));
    }

    function _startsWith(string memory s, string memory prefix) internal pure returns (bool) {
        bytes memory sb = bytes(s);
        bytes memory pb = bytes(prefix);
        if (pb.length > sb.length) return false;
        for (uint256 i = 0; i < pb.length; i++) {
            if (sb[i] != pb[i]) return false;
        }
        return true;
    }

    function _contains(string memory s, string memory needle) internal pure returns (bool) {
        bytes memory sb = bytes(s);
        bytes memory nb = bytes(needle);
        if (nb.length > sb.length) return false;
        for (uint256 i = 0; i + nb.length <= sb.length; i++) {
            bool ok = true;
            for (uint256 j = 0; j < nb.length; j++) {
                if (sb[i + j] != nb[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }

    function testOnERC721Received() public view {
        assertEq(ghouls.onERC721Received(address(0), address(0), 0, ""), LuckyGhouls.onERC721Received.selector);
    }
}
