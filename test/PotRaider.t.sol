// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, BBitsBurner, IERC20, console} from "@test/utils/BBitsTestUtils.sol";
import {PotRaider, IPotRaider, IV3Router, IV3Quoter, IBaseJackpot} from "@src/PotRaider.sol";
import {PotRaiderArt} from "@src/modules/PotRaiderArt.sol";
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
        IBaseJackpot lottery,
        PotRaiderArt artContract
    ) PotRaider(owner, mintPrice, burner, weth, usdc, uniswapRouter, uniswapQuoter, lottery, artContract) {}


}

/// @dev forge test --match-contract PotRaiderTest -vvv
contract PotRaiderTest is BBitsTestUtils {
    IV3Router public uniV3Router;
    IV3Quoter public uniV3Quoter;
    IBaseJackpot public lottery;
    PotRaiderArt public artContract;
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

        // Deploy the art contract
        artContract = new PotRaiderArt();

        potRaider = new PotRaiderHarness(owner, mintPrice, burner, WETH, USDC, uniV3Router, uniV3Quoter, lottery, artContract);
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

        (uint256 tickets,) = potRaider.lotteryPurchaseHistory(1);
        assertGt(tickets, 0);
        assertEq(potRaider.currentLotteryDay(), 1);
    }
}
