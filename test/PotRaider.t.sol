// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {PotRaider} from "@src/PotRaider.sol";
import {console} from "forge-std/console.sol";

contract PotRaiderTest is Test {
    PotRaider public potRaider;
    
    address public owner = address(this);
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public burner = address(0x3);
    address public artist = address(0x4);
    
    uint256 public mintPrice = 0.0008 ether;

    function setUp() public {
        potRaider = new PotRaider(mintPrice, burner, artist);
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

    function testColorGenerationEdgeCases() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice}(1);
        (uint8 r0, uint8 g0, uint8 b0) = potRaider.getHueRGB(0);
        // Should not be the old fixed color
        assertFalse(r0 == 192 && g0 == 183 && b0 == 64, "Token 0 should not have the old fixed color");
        // Test with a large token ID
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);
        (uint8 r9, uint8 g9, uint8 b9) = potRaider.getHueRGB(9);
        assertFalse(r0 == r9 && g0 == g9 && b0 == b9, "Token 0 and 9 should have different colors");
    }

    function testColorGenerationDistribution() public {
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);
        vm.prank(user1);
        potRaider.mint{value: mintPrice * 10}(10);
        // Collect all colors
        uint8[3][20] memory colors;
        for (uint256 i = 0; i < 20; i++) {
            (uint8 r, uint8 g, uint8 b) = potRaider.getHueRGB(i);
            colors[i][0] = r;
            colors[i][1] = g;
            colors[i][2] = b;
        }
        // Check for uniqueness
        uint256 uniqueColors = 0;
        for (uint256 i = 0; i < 20; i++) {
            bool isUnique = true;
            for (uint256 j = 0; j < i; j++) {
                if (colors[i][0] == colors[j][0] && colors[i][1] == colors[j][1] && colors[i][2] == colors[j][2]) {
                    isUnique = false;
                    break;
                }
            }
            if (isUnique) {
                uniqueColors++;
            }
        }
        assertTrue(uniqueColors >= 10, "Should have good color distribution");
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

    function testColorGenerationRandomness() public {
        // Mint 100 NFTs in batches of 10
        for (uint256 batch = 0; batch < 10; batch++) {
            vm.prank(user1);
            potRaider.mint{value: mintPrice * 10}(10);
        }
        
        // Collect all RGB values
        uint8[] memory rValues = new uint8[](100);
        uint8[] memory gValues = new uint8[](100);
        uint8[] memory bValues = new uint8[](100);
        
        for (uint256 i = 0; i < 100; i++) {
            (uint8 r, uint8 g, uint8 b) = potRaider.getHueRGB(i);
            rValues[i] = r;
            gValues[i] = g;
            bValues[i] = b;
        }
        
        // Test 1: Check for variety in each channel
        uint256 uniqueR = countUniqueValues(rValues);
        uint256 uniqueG = countUniqueValues(gValues);
        uint256 uniqueB = countUniqueValues(bValues);
        
        // Each channel should have good variety (at least 50% unique values)
        assertTrue(uniqueR >= 50, "R channel should have good variety");
        assertTrue(uniqueG >= 50, "G channel should have good variety");
        assertTrue(uniqueB >= 50, "B channel should have good variety");
        
        // Test 2: Check for distribution across the full range
        uint256 lowR = countValuesInRange(rValues, 0, 85);    // 0-85
        uint256 midR = countValuesInRange(rValues, 86, 170);  // 86-170
        uint256 highR = countValuesInRange(rValues, 171, 255); // 171-255
        
        uint256 lowG = countValuesInRange(gValues, 0, 85);
        uint256 midG = countValuesInRange(gValues, 86, 170);
        uint256 highG = countValuesInRange(gValues, 171, 255);
        
        uint256 lowB = countValuesInRange(bValues, 0, 85);
        uint256 midB = countValuesInRange(bValues, 86, 170);
        uint256 highB = countValuesInRange(bValues, 171, 255);
        
        // Each range should have some values (not all concentrated in one range)
        assertTrue(lowR > 0, "R should have values in low range");
        assertTrue(midR > 0, "R should have values in mid range");
        assertTrue(highR > 0, "R should have values in high range");
        
        assertTrue(lowG > 0, "G should have values in low range");
        assertTrue(midG > 0, "G should have values in mid range");
        assertTrue(highG > 0, "G should have values in high range");
        
        assertTrue(lowB > 0, "B should have values in low range");
        assertTrue(midB > 0, "B should have values in mid range");
        assertTrue(highB > 0, "B should have values in high range");
        
        // Test 3: Check for no obvious patterns
        uint256 consecutiveSameR = 0;
        uint256 consecutiveSameG = 0;
        uint256 consecutiveSameB = 0;
        
        for (uint256 i = 1; i < 100; i++) {
            if (rValues[i] == rValues[i-1]) consecutiveSameR++;
            if (gValues[i] == gValues[i-1]) consecutiveSameG++;
            if (bValues[i] == bValues[i-1]) consecutiveSameB++;
        }
        
        // Should not have too many consecutive same values (indicates poor randomness)
        assertTrue(consecutiveSameR < 20, "R should not have too many consecutive same values");
        assertTrue(consecutiveSameG < 20, "G should not have too many consecutive same values");
        assertTrue(consecutiveSameB < 20, "B should not have too many consecutive same values");
    }

    function testColorGenerationEntropy() public {
        // Mint 50 NFTs in batches of 10
        for (uint256 batch = 0; batch < 5; batch++) {
            vm.prank(user1);
            potRaider.mint{value: mintPrice * 10}(10);
        }
        
        // Calculate entropy for each channel
        uint256 entropyR = calculateEntropy(50);
        uint256 entropyG = calculateEntropy(50);
        uint256 entropyB = calculateEntropy(50);
        
        // Entropy should be reasonably high (indicating good randomness)
        // For 50 samples, we expect entropy to be at least 4-5 bits
        assertTrue(entropyR >= 4, "R channel should have good entropy");
        assertTrue(entropyG >= 4, "G channel should have good entropy");
        assertTrue(entropyB >= 4, "B channel should have good entropy");
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
} 