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
import {IV3Router, IV3Quoter} from "@src/BBitsBurnerNFT.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IBBitsBurnerNFT} from "@src/interfaces/IBBitsBurnerNFT.sol";

/// @dev forge test --match-contract BBitsBurnerNFTTest -vvv
contract BBitsBurnerNFTTest is BBitsTestUtils, IBBitsBurnerNFT {
    IV3Router public uniV3Router;
    IV3Quoter public uniV3Quoter;

    function setUp() public override {
        forkBase();
        vm.deal(owner, 1e20);

        WETH = IERC20(0x4200000000000000000000000000000000000006);
        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        bbits = BBITS(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
        uniV3Quoter = IV3Quoter(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);

        burnerNFT = new BBitsBurnerNFT(owner, bbits, uniV3Router, uniV3Quoter);

        /// @dev Owner contract set up
        addArt();
    }

    function testInit() public view {
        assertEq(burnerNFT.owner(), owner);
        assertEq(burnerNFT.dead(), 0x000000000000000000000000000000000000dEaD);
        assertEq(address(burnerNFT.WETH()), address(WETH));
        assertEq(address(burnerNFT.BBITS()), address(bbits));
        assertEq(address(burnerNFT.uniV3Router()), address(uniV3Router));
        assertEq(address(burnerNFT.uniV3Quoter()), address(uniV3Quoter));
        assertEq(burnerNFT.mintPriceInBBITS(), 1024e18);
        assertEq(burnerNFT.totalSupply(), 0);
        assertEq(WETH.allowance(address(burnerNFT), address(uniV3Router)), ~uint256(0));
    }

    /// MINT ///

    function testGetPriceInWETH() public {
        uint256 price = burnerNFT.mintPriceInWETH();
        //console.log("PRICE: ", price);
        assertGt(price, 0);
    }

    function testMintRevertConditions() public prank(owner) {
        uint256 price = burnerNFT.mintPriceInWETH();

        /// Insufficient ETH paid
        vm.expectRevert(InsufficientETHPaid.selector);
        burnerNFT.mint{value: price - 1}();
    }

    function testMintSuccessConditions() public prank(owner) {
        uint256 price = burnerNFT.mintPriceInWETH();
        uint256 burnBalanceBefore = bbits.balanceOf(burnerNFT.dead());
        assertEq(burnerNFT.balanceOf(owner), 0);

        burnerNFT.mint{value: price}();

        assertEq(burnBalanceBefore + burnerNFT.mintPriceInBBITS(), bbits.balanceOf(burnerNFT.dead()));
        assertEq(burnerNFT.totalSupply(), 1);
        assertEq(burnerNFT.balanceOf(owner), 1);
        assertEq(burnerNFT.ownerOf(0), owner);
    }

    /// OWNER ///

    function testSetMintPriceInBBITS() public prank(owner) {
        uint256 price = burnerNFT.mintPriceInWETH();

        /// double price in BBITS
        burnerNFT.setMintPriceInBBITS(2 * burnerNFT.mintPriceInBBITS());
        assertLt(price, burnerNFT.mintPriceInWETH());
    }

    /// ART ///

    function testDraw() public {
        /// Mint
        burnerNFT.mint{value: 1e17}();
        /// Art
        string memory image = burnerNFT.tokenURI(0);
        image;
        //console.log(image);
    }

    function addArt() internal override prank(owner) {
        /// Load some art
        IBBitsBurnerNFT.NamedBytes[] memory placeholder = new IBBitsBurnerNFT.NamedBytes[](1);
        /// Background
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: "AAAe"
        });
        burnerNFT.addArt(0, placeholder);
        /// Face
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: "CCCe"
        });
        burnerNFT.addArt(1, placeholder);
        /// Hair
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: "DDDe"
        });
        burnerNFT.addArt(2, placeholder);
        /// Eyes
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: "FFFe"
        });
        burnerNFT.addArt(3, placeholder);
        /// Mouth
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: "HHHe"
        });
        burnerNFT.addArt(4, placeholder);
    }
}
