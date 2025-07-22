// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {PotRaider} from "@src/PotRaider.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {MockLottery} from "@test/mocks/MockLottery.sol";
import {MockSwapRouter} from "@test/mocks/MockSwapRouter.sol";

contract PotRaiderTest is Test {
    PotRaider public potRaider;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public burner = address(0x3);
    address public artist = address(0x4);
    address public lotteryContract = address(0x5);
    address public usdcContract = address(0x6);
    address public uniswapRouter = address(0x7);
    
    uint256 public mintPrice = 0.0008 ether;

    function setUp() public {
        potRaider = new PotRaider(mintPrice, burner, artist);
        // Configure WETH address used for Uniswap interactions
        potRaider.setWETHAddress(0x4200000000000000000000000000000000000006);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testConstructor() public {
        assertEq(potRaider.name(), "Pot Raider");
        assertEq(potRaider.symbol(), "POTRAIDER");
        assertEq(potRaider.mintPrice(), mintPrice);
        assertEq(potRaider.burnerContract(), burner);
        assertEq(potRaider.artist(), artist);
        assertEq(potRaider.artistPercentage(), 1000); // 10%
        assertEq(potRaider.burnPercentage(), 1000); // 10%
        assertEq(potRaider.totalSupply(), 0);
        assertEq(potRaider.circulatingSupply(), 0);
        assertEq(potRaider.lotteryContract(), address(0));
        assertEq(potRaider.usdcContract(), address(0));
        assertEq(potRaider.uniswapRouter(), address(0));
    }

    function testMint() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        assertEq(potRaider.totalSupply(), 1);
        assertEq(potRaider.circulatingSupply(), 1);
        assertEq(potRaider.ownerOf(0), user1);
    }

    function testMintMultiple() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 3}(3);
        
        assertEq(potRaider.totalSupply(), 3);
        assertEq(potRaider.circulatingSupply(), 3);
        assertEq(potRaider.ownerOf(0), user1);
        assertEq(potRaider.ownerOf(1), user1);
        assertEq(potRaider.ownerOf(2), user1);
    }

    function testMintMaxQuantity() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);
        assertEq(potRaider.totalSupply(), 10);
        assertEq(potRaider.circulatingSupply(), 10);
    }

    function testMintLargeQuantity() public {
        uint256 largeQuantity = 100;
        vm.prank(user1);
        potRaider.mint{value: mintPrice * largeQuantity}(largeQuantity);
        assertEq(potRaider.totalSupply(), largeQuantity);
        assertEq(potRaider.circulatingSupply(), largeQuantity);
    }

    function testMintInsufficientPayment() public {
        vm.prank(user1);
        vm.expectRevert(PotRaider.InsufficientPayment.selector);
        potRaider.mint{value: mintPrice - 0.0001 ether}(1);
    }

    function testMintZeroQuantity() public {
        vm.prank(user1);
        vm.expectRevert(PotRaider.QuantityZero.selector);
        potRaider.mint{value: 0}(0);
    }

    function testColorGenerationDifferentColors() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);
        
        (uint8 r0, uint8 g0, uint8 b0) = potRaider.getHueRGB(0);
        (uint8 r1, uint8 g1, uint8 b1) = potRaider.getHueRGB(1);
        (uint8 r2, uint8 g2, uint8 b2) = potRaider.getHueRGB(2);
        (uint8 r5, uint8 g5, uint8 b5) = potRaider.getHueRGB(5);
        (uint8 r9, uint8 g9, uint8 b9) = potRaider.getHueRGB(9);
        
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
        (uint8 r1, uint8 g1, uint8 b1) = potRaider.getHueRGB(0);
        (uint8 r2, uint8 g2, uint8 b2) = potRaider.getHueRGB(0);
        (uint8 r3, uint8 g3, uint8 b3) = potRaider.getHueRGB(0);
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
            (uint8 r, uint8 g, uint8 b) = potRaider.getHueRGB(i);
            
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
        (uint8 r1, uint8 g1, uint8 b1) = potRaider.getHueRGB(0);
        (uint8 r2, uint8 g2, uint8 b2) = potRaider.getHueRGB(0);
        (uint8 r3, uint8 g3, uint8 b3) = potRaider.getHueRGB(0);
        
        // All calls should return the same color
        assertEq(r1, r2, "R should be deterministic");
        assertEq(g1, g2, "G should be deterministic");
        assertEq(b1, b2, "B should be deterministic");
        assertEq(r2, r3, "R should be deterministic");
        assertEq(g2, g3, "G should be deterministic");
        assertEq(b2, b3, "B should be deterministic");
    }

    function testDayFunction() public {
        // Day should start at 1 on deployment
        assertEq(potRaider.day(), 1, "Day should start at 1");
    }

    function testDayFunctionAfterTimePasses() public {
        uint256 deploymentTimestamp = potRaider.deploymentTimestamp();
        // Advance time by 1 day
        vm.warp(deploymentTimestamp + 1 days);
        assertEq(potRaider.day(), 2, "Day should be 2 after 1 day");
        
        // Advance time by another day (total 2 days from deployment)
        vm.warp(deploymentTimestamp + 2 days);
        assertEq(potRaider.day(), 3, "Day should be 3 after 2 days");
    }

    function testDayFunctionPartialDays() public {
        uint256 deploymentTimestamp = potRaider.deploymentTimestamp();
        // Advance time by 12 hours (half a day)
        vm.warp(deploymentTimestamp + 12 hours);
        assertEq(potRaider.day(), 1, "Day should still be 1 after 12 hours");
        
        // Advance time by 23 hours and 59 minutes (total 23:59 from deployment)
        vm.warp(deploymentTimestamp + 23 hours + 59 minutes);
        assertEq(potRaider.day(), 1, "Day should still be 1 after 23 hours 59 minutes");
        
        // Advance time by 1 more minute to complete the day (24 hours)
        vm.warp(deploymentTimestamp + 24 hours);
        assertEq(potRaider.day(), 2, "Day should be 2 after exactly 24 hours");
    }

    function testDayFunctionMultipleDays() public {
        // Advance time by 7 days
        vm.warp(block.timestamp + 7 days);
        assertEq(potRaider.day(), 8, "Day should be 8 after 7 days");
        
        // Advance time by 30 days
        vm.warp(block.timestamp + 30 days);
        assertEq(potRaider.day(), 38, "Day should be 38 after 30 more days");
    }

    function testDayFunctionEdgeCases() public {
        // Test with very small time increments
        vm.warp(block.timestamp + 1 seconds);
        assertEq(potRaider.day(), 1, "Day should be 1 after 1 second");
        
        vm.warp(block.timestamp + 1 minutes);
        assertEq(potRaider.day(), 1, "Day should be 1 after 1 minute");
        
        vm.warp(block.timestamp + 1 hours);
        assertEq(potRaider.day(), 1, "Day should be 1 after 1 hour");
        
        // Test with exactly 24 hours
        vm.warp(block.timestamp + 24 hours);
        assertEq(potRaider.day(), 2, "Day should be 2 after exactly 24 hours");
    }

    function testDayFunctionLargeTimeGaps() public {
        uint256 deploymentTimestamp = potRaider.deploymentTimestamp();
        // Test with a large time gap (1 year)
        vm.warp(deploymentTimestamp + 365 days);
        assertEq(potRaider.day(), 366, "Day should be 366 after 1 year");
        
        // Test with multiple years (total 2 years from deployment)
        vm.warp(deploymentTimestamp + 2 * 365 days);
        assertEq(potRaider.day(), 731, "Day should be 731 after 2 years");
    }

    function testDayFunctionConsistency() public {
        // Call day() multiple times without time changes
        uint256 day1 = potRaider.day();
        uint256 day2 = potRaider.day();
        uint256 day3 = potRaider.day();
        
        assertEq(day1, day2, "Day should be consistent");
        assertEq(day2, day3, "Day should be consistent");
        assertEq(day1, 1, "Day should start at 1");
    }

    function testDayFunctionDeploymentTimestamp() public {
        // Get the deployment timestamp
        uint256 deploymentTimestamp = potRaider.deploymentTimestamp();
        
        // Verify that the day calculation matches our expectation
        uint256 expectedDay = ((block.timestamp - deploymentTimestamp) / 1 days) + 1;
        uint256 actualDay = potRaider.day();
        
        assertEq(actualDay, expectedDay, "Day calculation should match expected formula");
    }

    function testExchange() public {
        // Mint an NFT and add some ETH to the contract
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        // Add ETH to contract treasury
        vm.deal(address(potRaider), 1 ether);
        
        uint256 initialBalance = user1.balance;
        uint256 initialCirculatingSupply = potRaider.circulatingSupply();
        
        vm.prank(user1);
        potRaider.exchange(0);
        
        assertEq(potRaider.circulatingSupply(), initialCirculatingSupply - 1, "Circulating supply should decrease");
        assertTrue(user1.balance > initialBalance, "User should receive ETH");
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.ownerOf(0);
    }

    function testExchangeNotOwner() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        vm.prank(user2);
        vm.expectRevert(PotRaider.NotOwner.selector);
        potRaider.exchange(0);
    }

    function testExchangeNoTreasury() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        // Ensure contract has no ETH balance
        vm.deal(address(potRaider), 0);
        
        vm.prank(user1);
        vm.expectRevert(PotRaider.NoTreasuryAvailable.selector);
        potRaider.exchange(0);
    }

    function testExchangeNoCirculatingSupply() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        // Burn the NFT directly
        vm.prank(user1);
        potRaider.burn(0);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.exchange(0);
    }

    function testBurn() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        uint256 initialCirculatingSupply = potRaider.circulatingSupply();
        
        vm.prank(user1);
        potRaider.burn(0);
        
        assertEq(potRaider.circulatingSupply(), initialCirculatingSupply - 1, "Circulating supply should decrease");
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        potRaider.ownerOf(0);
    }

    function testSetMintPrice() public {
        uint256 newPrice = 0.001 ether;
        potRaider.setMintPrice(newPrice);
        assertEq(potRaider.mintPrice(), newPrice);
    }

    function testSetBurnPercentage() public {
        uint256 newPercentage = 500; // 5% (500 basis points)
        potRaider.setBurnPercentage(newPercentage);
        assertEq(potRaider.burnPercentage(), newPercentage);
    }

    function testSetBurnPercentageExceeds100() public {
        vm.expectRevert("Burn percentage cannot exceed 100%");
        potRaider.setBurnPercentage(10001);
    }

    function testSetPercentages() public {
        uint256 newBurnPercentage = 500; // 5% (500 basis points)
        uint256 newArtistPercentage = 2000; // 20% (2000 basis points)
        
        potRaider.setPercentages(newBurnPercentage, newArtistPercentage);
        
        assertEq(potRaider.burnPercentage(), newBurnPercentage);
        assertEq(potRaider.artistPercentage(), newArtistPercentage);
    }

    function testSetPercentagesExceeds100() public {
        vm.expectRevert("Total percentages cannot exceed 100%");
        potRaider.setPercentages(6000, 5000); // 60% + 50% = 110%
    }

    function testSetPercentagesBurnExceeds100() public {
        vm.expectRevert("Burn percentage cannot exceed 100%");
        potRaider.setPercentages(10001, 1000);
    }

    function testSetPercentagesArtistExceeds100() public {
        vm.expectRevert("Artist percentage cannot exceed 100%");
        potRaider.setPercentages(1000, 10001);
    }

    function testSetBurnerContract() public {
        address newBurner = address(0x999);
        potRaider.setBurnerContract(newBurner);
        assertEq(potRaider.burnerContract(), newBurner);
    }

    function testPauseUnpause() public {
        potRaider.pause();
        assertTrue(potRaider.paused());
        
        potRaider.unpause();
        assertFalse(potRaider.paused());
    }

    function testMintWhenPaused() public {
        potRaider.pause();
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        potRaider.mint{value: mintPrice}(1);
    }

    function testExchangeWhenPaused() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        vm.deal(address(potRaider), 1 ether);
        
        potRaider.pause();
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        potRaider.exchange(0);
    }

    function testTokenURI() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        string memory uri = potRaider.tokenURI(0);
        assertTrue(bytes(uri).length > 0, "Token URI should not be empty");
        assertTrue(
            keccak256(bytes(uri)) != keccak256(bytes("")),
            "Token URI should not be empty string"
        );
    }

    function testTokenURINonexistentToken() public {
        vm.expectRevert("ERC721Metadata: URI query for nonexistent token");
        potRaider.tokenURI(999);
    }

    function testContractURI() public {
        string memory uri = potRaider.contractURI();
        assertEq(uri, "", "Contract URI should be empty by default");
    }

    function testSetContractURI() public {
        string memory newURI = "https://example.com/metadata.json";
        potRaider.setContractURI(newURI);
        assertEq(potRaider.contractURI(), newURI);
    }

    function testSetLotteryContract() public {
        potRaider.setLotteryContract(lotteryContract);
        assertEq(potRaider.lotteryContract(), lotteryContract);
    }

    function testSetUSDCContract() public {
        potRaider.setUSDCContract(usdcContract);
        assertEq(potRaider.usdcContract(), usdcContract);
    }

    function testSetUniswapRouter() public {
        potRaider.setUniswapRouter(uniswapRouter);
        assertEq(potRaider.uniswapRouter(), uniswapRouter);
    }

    function testPurchaseLotteryTicketNotConfigured() public {
        vm.expectRevert(PotRaider.LotteryNotConfigured.selector);
        potRaider.purchaseLotteryTicket();
    }

    function testPurchaseLotteryTicketUSDCNotConfigured() public {
        potRaider.setLotteryContract(lotteryContract);
        
        vm.expectRevert(PotRaider.UniswapQuoterNotConfigured.selector);
        potRaider.purchaseLotteryTicket();
    }

    function testGetCurrentLotteryRoundNotConfigured() public {
        vm.expectRevert(PotRaider.LotteryNotConfigured.selector);
        potRaider.getCurrentLotteryRound();
    }

    function testGetLotteryJackpotNotConfigured() public {
        vm.expectRevert(PotRaider.LotteryNotConfigured.selector);
        potRaider.getLotteryJackpot();
    }

    function testGetDailyPurchaseAmountNotConfigured() public {
        vm.expectRevert(PotRaider.LotteryNotConfigured.selector);
        potRaider.getDailyPurchaseAmount();
    }

    function testWithdrawWinningsNotConfigured() public {
        vm.expectRevert(PotRaider.LotteryNotConfigured.selector);
        potRaider.withdrawWinnings();
    }

    function testPurchaseLotteryTicketQuoterCallFailed() public {
        // Deploy a mock quoter but do not set returnAmount or use an address with no code
        address badQuoter = address(0xdeadbeef);
        potRaider.setLotteryContract(lotteryContract);
        potRaider.setUSDCContract(usdcContract);
        potRaider.setUniswapRouter(uniswapRouter);
        potRaider.setUniswapQuoter(badQuoter);

        // Fund the contract with a small amount of ETH
        vm.deal(address(potRaider), 1 ether);

        // Expect revert (no selector, as staticcall may revert with no data)
        vm.expectRevert();
        potRaider.purchaseLotteryTicket();
    }

    function testPurchaseLotteryTicketInsufficientUSDC() public {
        // Deploy and configure the mock quoter
        MockQuoter mockQuoter = new MockQuoter();
        potRaider.setLotteryContract(lotteryContract);
        potRaider.setUSDCContract(usdcContract);
        potRaider.setUniswapRouter(uniswapRouter);
        potRaider.setUniswapQuoter(address(mockQuoter));

        // Fund the contract with a small amount of ETH
        vm.deal(address(potRaider), 1 ether);

        // Set the mock quoter to return less than 1 USDC (LOTTERY_TICKET_PRICE_USD * 10^USDC_DECIMALS)
        uint256 lessThanOneUSDC = (potRaider.LOTTERY_TICKET_PRICE_USD() * (10 ** potRaider.USDC_DECIMALS())) - 1;
        mockQuoter.setReturnAmount(lessThanOneUSDC);

        // Expect revert (no selector, as staticcall may revert with no data)
        vm.expectRevert();
        potRaider.purchaseLotteryTicket();
    }

    function testExchangeWithUSDC() public {
        // Mint an NFT
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        
        // Set up USDC contract
        potRaider.setUSDCContract(usdcContract);
        
        // Fund the contract with ETH and USDC
        vm.deal(address(potRaider), 2 ether);
        
        // Mock USDC balance for the contract (1,000,000 USDC = 1 USDC with 6 decimals)
        uint256 usdcAmount = 1_000_000; // 1 USDC
        vm.mockCall(
            usdcContract,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(potRaider)),
            abi.encode(usdcAmount)
        );
        
        // Mock USDC transfer to user1
        vm.mockCall(
            usdcContract,
            abi.encodeWithSelector(IERC20.transfer.selector, user1, usdcAmount / 1),
            abi.encode(true)
        );
        
        // Exchange the NFT
        vm.prank(user1);
        potRaider.exchange(0);
        
        // Verify NFT was burned
        assertEq(potRaider.circulatingSupply(), 0);
        
        // Verify ETH was sent (user1 starts with 10 ether, spends mintPrice, then receives 2 ether)
        assertEq(user1.balance, 10 ether - mintPrice + 2 ether);
    }

    function testPurchaseLotteryTicketSuccess() public {
        MockQuoter mockQuoter = new MockQuoter();
        MockSwapRouter mockRouter = new MockSwapRouter();
        MockLottery mockLottery = new MockLottery(1 days);

        potRaider.setLotteryContract(address(mockLottery));
        potRaider.setUSDCContract(usdcContract);
        potRaider.setUniswapRouter(address(mockRouter));
        potRaider.setUniswapQuoter(address(mockQuoter));

        vm.deal(address(potRaider), 1 ether);

        uint256 ticketPrice =
            potRaider.LOTTERY_TICKET_PRICE_USD() * (10 ** potRaider.USDC_DECIMALS());
        uint256 expectedUSDC = (ticketPrice * 102) / 100;
        mockQuoter.setReturnAmount(expectedUSDC);
        mockRouter.setReturnAmount(expectedUSDC);

        uint256 dailyAmount = potRaider.getDailyPurchaseAmount();

        vm.expectEmit(true, true, false, true);
        emit PotRaider.LotteryTicketPurchased(0, dailyAmount);
        potRaider.purchaseLotteryTicket();

        assertEq(mockRouter.receivedETH(), dailyAmount, "Incorrect ETH sent");
        assertEq(mockLottery.purchaseValue(), expectedUSDC, "Incorrect USDC value");
        assertEq(mockLottery.purchaseRecipient(), address(potRaider));
        (,,,,,,uint256 amountOutMinimum,) = mockRouter.lastParams();
        assertEq(amountOutMinimum, (expectedUSDC * 95) / 100, "Incorrect slippage amount");
        assertEq(potRaider.lotteryPurchasedForDay(0), dailyAmount);
    }

    function testWithdrawWinningsSuccess() public {
        MockLottery mockLottery = new MockLottery(1 days);
        potRaider.setLotteryContract(address(mockLottery));

        potRaider.withdrawWinnings();

        assertTrue(mockLottery.withdrawCalled());
    }

    // Helper function to count unique values in an array
    function countUniqueValues(uint8[] memory values) internal pure returns (uint256) {
        uint256 uniqueCount = 0;
        for (uint256 i = 0; i < values.length; i++) {
            bool isUnique = true;
            for (uint256 j = 0; j < i; j++) {
                if (values[i] == values[j]) {
                    isUnique = false;
                    break;
                }
            }
            if (isUnique) {
                uniqueCount++;
            }
        }
        return uniqueCount;
    }

    // Helper function to count values in a specific range
    function countValuesInRange(uint8[] memory values, uint256 min, uint256 max) internal pure returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] >= min && values[i] <= max) {
                count++;
            }
        }
        return count;
    }

    // Helper function to calculate entropy (simplified version)
    function calculateEntropy(uint256 sampleSize) internal view returns (uint256) {
        uint8[] memory rValues = new uint8[](sampleSize);
        uint8[] memory gValues = new uint8[](sampleSize);
        uint8[] memory bValues = new uint8[](sampleSize);
        
        for (uint256 i = 0; i < sampleSize; i++) {
            (uint8 r, uint8 g, uint8 b) = potRaider.getHueRGB(i);
            rValues[i] = r;
            gValues[i] = g;
            bValues[i] = b;
        }
        
        // Calculate unique values as a proxy for entropy
        uint256 uniqueR = countUniqueValues(rValues);
        uint256 uniqueG = countUniqueValues(gValues);
        uint256 uniqueB = countUniqueValues(bValues);
        
        // Return average unique values (higher = more entropy)
        return (uniqueR + uniqueG + uniqueB) / 3;
    }

    // ========== LOTTERY PARTICIPATION DAYS TESTS ==========

    function testLotteryParticipationDaysDefault() public {
        assertEq(potRaider.lotteryParticipationDays(), 365);
    }

    function testSetLotteryParticipationDays() public {
        uint256 newDuration = 180;
        potRaider.setLotteryParticipationDays(newDuration);
        assertEq(potRaider.lotteryParticipationDays(), newDuration);
    }

    function testSetLotteryParticipationDaysOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        potRaider.setLotteryParticipationDays(180);
    }

    function testSetLotteryParticipationDaysZero() public {
        vm.expectRevert("Duration must be greater than 0");
        potRaider.setLotteryParticipationDays(0);
    }

    function testSetLotteryParticipationDaysMultipleUpdates() public {
        // Set to different values
        potRaider.setLotteryParticipationDays(180);
        assertEq(potRaider.lotteryParticipationDays(), 180);
        
        potRaider.setLotteryParticipationDays(730);
        assertEq(potRaider.lotteryParticipationDays(), 730);
        
        potRaider.setLotteryParticipationDays(365);
        assertEq(potRaider.lotteryParticipationDays(), 365);
    }

    function testLotteryParticipationDaysEdgeCases() public {
        // Test edge cases for the setter function
        
        // Test setting to 1 day
        potRaider.setLotteryParticipationDays(1);
        assertEq(potRaider.lotteryParticipationDays(), 1);
        
        // Test setting to a large number
        uint256 largeNumber = 1000;
        potRaider.setLotteryParticipationDays(largeNumber);
        assertEq(potRaider.lotteryParticipationDays(), largeNumber);
        
        // Test setting back to default
        potRaider.setLotteryParticipationDays(365);
        assertEq(potRaider.lotteryParticipationDays(), 365);
    }

    function testLotteryParticipationDaysBasicFunctionality() public {
        // Test that the setter function works correctly
        uint256 originalDuration = potRaider.lotteryParticipationDays();
        assertEq(originalDuration, 365);
        
        // Set to a new value
        uint256 newDuration = 180;
        potRaider.setLotteryParticipationDays(newDuration);
        assertEq(potRaider.lotteryParticipationDays(), newDuration);
        
        // Set back to original
        potRaider.setLotteryParticipationDays(originalDuration);
        assertEq(potRaider.lotteryParticipationDays(), originalDuration);
    }
} 

// Minimal mock for Uniswap V3 Quoter
contract MockQuoter {
    uint256 public returnAmount;
    function setReturnAmount(uint256 _amount) external {
        returnAmount = _amount;
    }
    function quoteExactInputSingle(address, address, uint24, uint256, uint160) external view returns (uint256) {
        return returnAmount;
    }
} 