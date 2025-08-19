// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IBaseJackpot} from "@src/interfaces/baseJackpot/IBaseJackpot.sol";
import {BBitsBurner} from "src/BBitsBurner.sol";
import {PotRaider} from "@src/PotRaider.sol";
import {PotRaiderArt} from "@src/modules/PotRaiderArt.sol";

contract PotRaiderDeploy is Script {
    PotRaider public potRaider;
    PotRaiderArt public artContract;

    BBitsBurner public burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
    IERC20 public WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 public USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IV3Router public uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
    IV3Quoter public uniV3Quoter = IV3Quoter(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);
    IBaseJackpot public lotteryContract = IBaseJackpot(0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95);

    function run() external {
        vm.startBroadcast();

        // Deploy the art contract first
        artContract = new PotRaiderArt();

        // Deploy the main PotRaider contract
        potRaider = new PotRaider(
            msg.sender,
            0.0011 ether,
            burner,
            WETH,
            USDC,
            uniV3Router,
            uniV3Quoter,
            lotteryContract,
            artContract
        );

        potRaider.setLotteryReferrer(0x1d671d1B191323A38490972D58354971E5c1cd2A);
        vm.stopBroadcast();
    }
}
