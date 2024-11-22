// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {BBitsBurnerNFT} from "@src/BBitsBurnerNFT.sol";
import {BBitsBurnerNFTArtInstall} from "@script/burnerNFT/BBitsBurnerNFTArtInstall.sol";

contract BBitsBurnerNFTDeploy is Script, BBitsBurnerNFTArtInstall {
    function run() external {
        //        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();

        IERC20 bbits = IERC20(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        IV3Router uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
        IV3Quoter uniV3Quoter = IV3Quoter(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);

        burnerNFT = new BBitsBurnerNFT(msg.sender, bbits, uniV3Router, uniV3Quoter);
        _addArt();

        vm.stopBroadcast();
    }
}
