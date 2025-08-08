// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, IERC20, console} from "@test/utils/BBitsTestUtils.sol";
import {PotRaider, IPotRaider, IV3Router, IV3Quoter, IBaseJackpot} from "@src/PotRaider.sol";
import {MockERC20} from "@test/mocks/MockERC20.sol";
import {ReentrantMint} from "@test/mocks/ReentrantMint.sol";

contract PotRaiderHarness is PotRaider {
    constructor(
        address owner,
        uint256 mintPrice,
        BBitsBurner burner,
        IERC20 weth,
        IERC20 usdc,
        IV3Router uniswapRouter,
        IV3Quoter uniswapQuoter,
        IBaseJackpot lottery
    ) PotRaider(owner, mintPrice, burner, weth, usdc, uniswapRouter, uniswapQuoter, lottery) {}

    function expose_getHueRGB(uint256 tokenId) external pure returns (uint8 r, uint8 g, uint8 b) {
        return getHueRGB(tokenId);
    }
}

/// @dev forge test --match-contract PotRaiderTest -vvv
contract PotRaiderTest is BBitsTestUtils {
    IV3Router public uniV3Router;
    IV3Quoter public uniV3Quoter;
    IBaseJackpot public lottery;
    uint256 public mintPrice = 0.0013 ether;

    function setUp() public override {
        forkBase();

        owner = address(0x69);
        user0 = address(0x100);
        user1 = address(0x200);
        vm.deal(owner, 1e18);
        vm.deal(user0, 1e18);
        vm.deal(user1, 1e18);

        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        WETH = IERC20(0x4200000000000000000000000000000000000006);
        USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
        uniV3Quoter = IV3Quoter(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);
        lottery = IBaseJackpot(0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95);

        potRaider = new PotRaiderHarness(owner, mintPrice, burner, WETH, USDC, uniV3Router, uniV3Quoter, lottery);
    }

    function testConstructor() public {
        assertEq(potRaider.name(), "Pot Raider");
        assertEq(potRaider.symbol(), "POTRAIDER");
        assertEq(address(potRaider.bbitsBurner()), address(burner));
        assertEq(address(potRaider.weth()), address(WETH));
        assertEq(address(potRaider.usdc()), address(USDC));
        assertEq(address(potRaider.uniswapRouter()), address(uniV3Router));
        assertEq(address(potRaider.uniswapQuoter()), address(uniV3Quoter));
        assertEq(address(potRaider.lottery()), address(lottery));
        assertEq(potRaider.lotteryTicketPriceUSD(), 1e6);
        assertEq(potRaider.maxMint(), 50);
        assertEq(potRaider.MAX_SUPPLY(), 1000);
        assertEq(potRaider.totalSupply(), 0);
        assertEq(potRaider.circulatingSupply(), 0);
        assertEq(potRaider.mintPrice(), mintPrice);
        assertEq(potRaider.burnPercentage(), 2000);
        assertEq(potRaider.lotteryParticipationDays(), 365);
        assertEq(potRaider.currentLotteryDay(), 0);
    }

    function testMintMultiple() public prank(user1) {
        potRaider.mint{value: mintPrice * 3}(3);

        assertEq(potRaider.totalSupply(), 3);
        assertEq(potRaider.circulatingSupply(), 3);
        assertEq(potRaider.ownerOf(0), user1);
        assertEq(potRaider.ownerOf(1), user1);
        assertEq(potRaider.ownerOf(2), user1);
    }

    function testMintFailureConditions() public prank(user1) {
        uint256 largeQuantity = potRaider.maxMint() + 1;
        vm.expectRevert(IPotRaider.MaxMintPerCallExceeded.selector);
        potRaider.mint{value: mintPrice * largeQuantity}(largeQuantity);

        vm.expectRevert(IPotRaider.InsufficientPayment.selector);
        potRaider.mint{value: mintPrice - 1}(1);

        vm.expectRevert(IPotRaider.QuantityZero.selector);
        potRaider.mint{value: 0}(0);
    }

    /// ART ///

    function testColorGenerationDifferentColors() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);

        (uint8 r0, uint8 g0, uint8 b0) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        (uint8 r1, uint8 g1, uint8 b1) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(1);
        (uint8 r2, uint8 g2, uint8 b2) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(2);
        (uint8 r5, uint8 g5, uint8 b5) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(5);
        (uint8 r9, uint8 g9, uint8 b9) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(9);

        // Check that different token IDs produce different colors
        assertFalse(r0 == r1 && g0 == g1 && b0 == b1, "Token 0 and 1 should have different colors");
        assertFalse(r1 == r2 && g1 == g2 && b1 == b2, "Token 1 and 2 should have different colors");
        assertFalse(r0 == r2 && g0 == g2 && b0 == b2, "Token 0 and 2 should have different colors");
        assertFalse(r0 == r5 && g0 == g5 && b0 == b5, "Token 0 and 5 should have different colors");
        assertFalse(r0 == r9 && g0 == g9 && b0 == b9, "Token 0 and 9 should have different colors");
    }

    function testColorGenerationConsistency() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        (uint8 r1, uint8 g1, uint8 b1) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        (uint8 r2, uint8 g2, uint8 b2) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        (uint8 r3, uint8 g3, uint8 b3) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        assertEq(r1, r2, "R should be consistent");
        assertEq(g1, g2, "G should be consistent");
        assertEq(b1, b2, "B should be consistent");
        assertEq(r2, r3, "R should be consistent");
        assertEq(g2, g3, "G should be consistent");
        assertEq(b2, b3, "B should be consistent");
    }

    function testColorGenerationRGBRange() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 5}(5);

        for (uint256 i = 0; i < 5; i++) {
            (uint8 r, uint8 g, uint8 b) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(i);

            // RGB values should be within valid range (0-255)
            assertTrue(r >= 0 && r <= 255, "R value should be in valid range");
            assertTrue(g >= 0 && g <= 255, "G value should be in valid range");
            assertTrue(b >= 0 && b <= 255, "B value should be in valid range");

            // Colors should not be pure black or white (which would indicate issues)
            assertFalse(r == 0 && g == 0 && b == 0, "Color should not be pure black");
            assertFalse(r == 255 && g == 255 && b == 255, "Color should not be pure white");
        }
    }

    function testColorGenerationDeterministic() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);

        // Get colors multiple times for the same token ID
        (uint8 r1, uint8 g1, uint8 b1) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        (uint8 r2, uint8 g2, uint8 b2) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);
        (uint8 r3, uint8 g3, uint8 b3) = PotRaiderHarness(payable(address(potRaider))).expose_getHueRGB(0);

        // All calls should return the same color
        assertEq(r1, r2, "R should be deterministic");
        assertEq(g1, g2, "G should be deterministic");
        assertEq(b1, b2, "B should be deterministic");
        assertEq(r2, r3, "R should be deterministic");
        assertEq(g2, g3, "G should be deterministic");
        assertEq(b2, b3, "B should be deterministic");
    }

    /// EXCHANGE ///

    function testExchange() public prank(user1) {
        // Mint an NFT and add some ETH to the contract
        potRaider.mint{value: mintPrice}(1);

        // Add ETH to contract treasury
        vm.deal(address(potRaider), 1 ether);

        uint256 initialBalance = user1.balance;
        uint256 initialCirculatingSupply = potRaider.circulatingSupply();

        potRaider.exchange(0);

        assertEq(potRaider.circulatingSupply(), initialCirculatingSupply - 1, "Circulating supply should decrease");
        assertTrue(user1.balance > initialBalance, "User should receive ETH");

        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.ownerOf(0);
    }

    function testExchangeFailureConditions() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);

        vm.prank(user2);
        vm.expectRevert(IPotRaider.NotOwner.selector);
        potRaider.exchange(0);

        // Ensure contract has no ETH balance
        vm.deal(address(potRaider), 0);
        vm.prank(user1);
        vm.expectRevert(IPotRaider.NoTreasuryAvailable.selector);
        potRaider.exchange(0);

        // Burn the NFT directly
        vm.prank(user1);
        potRaider.burn(0);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.exchange(0);
    }

    /// BURN ///

    function testBurn() public prank(user1) {
        potRaider.mint{value: mintPrice}(1);

        uint256 initialCirculatingSupply = potRaider.circulatingSupply();
        potRaider.burn(0);

        assertEq(potRaider.circulatingSupply(), initialCirculatingSupply - 1, "Circulating supply should decrease");
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.ownerOf(0);
    }

    /// SETTINGS ///

    function testSetMintPrice() public prank(owner) {
        uint256 newPrice = 0.001 ether;
        potRaider.setMintPrice(newPrice);
        assertEq(potRaider.mintPrice(), newPrice);
    }

    function testSetBurnPercentage() public prank(owner) {
        uint16 newBurnPercentage = 500; // 5% (500 basis points)

        potRaider.setBurnPercentage(newBurnPercentage);

        assertEq(potRaider.burnPercentage(), newBurnPercentage);
    }

    function testSetBurnPercentageExceeds100() public prank(owner) {
        vm.expectRevert(IPotRaider.InvalidPercentage.selector);
        potRaider.setBurnPercentage(10001);
    }

    function testSetLotteryParticipationDays() public prank(owner) {
        uint256 newDuration = 180;
        potRaider.setLotteryParticipationDays(newDuration);
        assertEq(potRaider.lotteryParticipationDays(), newDuration);
    }

    function testPauseUnpause() public prank(owner) {
        potRaider.pause();
        assertTrue(potRaider.paused());

        potRaider.unpause();
        assertFalse(potRaider.paused());
    }

    function testMintWhenPaused() public {
        vm.prank(owner);
        potRaider.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        potRaider.mint{value: mintPrice}(1);
    }

    function testExchangeWhenPaused() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        vm.deal(address(potRaider), 1 ether);

        vm.prank(owner);
        potRaider.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        potRaider.exchange(0);
    }

    /// EMERGENCY WITHDRAW ///

    function testDepositERC20AndEmergencyWithdraw() public prank(owner) {
        MockERC20 token = new MockERC20("Mock", "MCK");
        token.mint(address(potRaider), 500);
        assertEq(token.balanceOf(address(potRaider)), 500);

        potRaider.emergencyWithdraw(address(token));
        assertEq(token.balanceOf(address(owner)), 500);
        assertEq(token.balanceOf(address(potRaider)), 0);
    }

    function testEmergencyWithdrawETH() public {
        vm.prank(owner);
        potRaider.transferOwnership(user1);
        vm.deal(address(potRaider), 2 ether);
        uint256 before = user1.balance;
        vm.prank(user1);
        potRaider.emergencyWithdraw(address(0));
        assertEq(user1.balance, before + 2 ether);
    }

    /// METADATA ///

    function testTokenURI() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);

        string memory uri = potRaider.tokenURI(0);
        assertTrue(bytes(uri).length > 0, "Token URI should not be empty");
        assertTrue(keccak256(bytes(uri)) != keccak256(bytes("")), "Token URI should not be empty string");
    }

    function testMaxSupply() public {
        vm.deal(user1, mintPrice * potRaider.MAX_SUPPLY());
        vm.startPrank(user1);
        for (uint256 i = 0; i < potRaider.MAX_SUPPLY() / potRaider.maxMint(); i++) {
            potRaider.mint{value: mintPrice * potRaider.maxMint()}(potRaider.maxMint());
        }
        vm.stopPrank();

        assertEq(potRaider.totalSupply(), potRaider.MAX_SUPPLY());

        vm.deal(user1, mintPrice);
        vm.prank(user1);
        vm.expectRevert(IPotRaider.MaxSupplyReached.selector);
        potRaider.mint{value: mintPrice}(1);
    }

    function testTokenURINonexistentToken() public {
        vm.expectRevert("ERC721NonexistentToken(999)");
        potRaider.tokenURI(999);
    }

    function testSetContractURI() public prank(owner) {
        string memory uri = potRaider.contractURI();
        assertEq(uri, "", "Contract URI should be empty by default");

        string memory newURI = "https://example.com/metadata.json";
        potRaider.setContractURI(newURI);
        assertEq(potRaider.contractURI(), newURI);
    }

    /// FLOW ///

    function testMintAndPurchase() public prank(user0) {
        potRaider.mint{value: 50 * mintPrice}(50);
        potRaider.mint{value: 50 * mintPrice}(50);
        // Ensure the contract has enough ETH to buy at least one ticket
        vm.deal(address(potRaider), 1 ether);

        potRaider.purchaseLotteryTicket();

        (uint256 tickets,) = potRaider.lotteryPurchaseHistory(0);
        assertGt(tickets, 0);
    }
}
