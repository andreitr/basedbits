// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {PotRaider} from "@src/PotRaider.sol";

contract PotRaiderDeploy is Script {
        
    PotRaider public potRaider;
    address public burner = 0x1595409cbAEf3dD2485107fb1e328fA0fA505c10;
    address public artist = 0x1d671d1B191323A38490972D58354971E5c1cd2A;
    address public usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // USDC on Base
    address public uniswapRouter = 0x2626664c2603336E57B271c5C0b26F421741e481; // Uniswap V3 Router on Base

    function run() external {
        vm.startBroadcast();

        potRaider = new PotRaider(
            0.0013 ether,
            burner,                 // burnerContract
            artist                  // artist
        );

        // Set the USDC contract address
        potRaider.setUSDCContract(usdc);

        // Set the Uniswap router address
        potRaider.setUniswapRouter(uniswapRouter);

        // Set the lottery referrer address
        potRaider.setLotteryReferrer(0xDAdA5bAd8cdcB9e323d0606d081E6Dc5D3a577a1);

        vm.stopBroadcast();
    }
} 