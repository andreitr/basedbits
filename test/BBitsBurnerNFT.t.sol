// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils,
    BBitsBurner,
    BBitsBurnerNFT,
    IBBitsBurner,
    BBITS,
    IERC20,
    console
} from "@test/utils/BBitsTestUtils.sol";
import {IV3Router, IV3Pool} from "@src/BBitsBurnerNFT.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract BBitsBurnerNFTTest -vvv
contract BBitsBurnerNFTTest is BBitsTestUtils {
    IV3Router public uniV3Router;
    IV3Pool public uniV3Pool;

    function setUp() public override {
        forkBase();
        vm.deal(owner, 1e20);

        WETH = IERC20(0x4200000000000000000000000000000000000006);
        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        bbits = BBITS(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
        uniV3Pool = IV3Pool(0xc229495845BBB34997e2143799856Af61448582F);

        burnerNFT = new BBitsBurnerNFT(owner, bbits, uniV3Router, uniV3Pool);
    }

    function testInit() public view {}

    function testPrice() public view {
        uint256 price = burnerNFT.getPrice();
        console.log("PRICE: ", price);
    }
}