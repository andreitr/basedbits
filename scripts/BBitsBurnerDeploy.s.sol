// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {BBitsBurner, IV2Router, IV3Router} from "../src/BBitsBurner.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract BBitsBurnerDeploy is Script {
    function run() external {
        vm.startBroadcast();

        /// @dev Assumes deployment to Base mainnet
        IERC20 WETH = IERC20(0x4200000000000000000000000000000000000006);
        IERC20 bbits = IERC20(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        IV2Router uniV2Router = IV2Router(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        IV3Router uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
        address owner = 0x4FCfb1b0A8B44fE0A7c0DcfA4EF36d48d758C64D;
        BBitsBurner burner = new BBitsBurner(owner, WETH, bbits, uniV2Router, uniV3Router);
        vm.stopBroadcast();
    }
}