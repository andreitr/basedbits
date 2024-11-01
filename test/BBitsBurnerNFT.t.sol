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
        placeholder[0] =
            IBBitsBurnerNFT.NamedBytes({core: '<rect width="27" height="27" fill="#0000AA"/>', name: "AAAe"});
        burnerNFT.addArt(0, placeholder);
        /// Face
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<path d="M9 23V24H16V23H17V18H16V15H15V13H14V11H13V8H12V10H11V12H10V14H9V16H8V19.5V23H9Z" fill="#FF0000"/><path d="M12 6V5H13V6H12Z" fill="#FF0000"/><path d="M14 10V9H15V10H14Z" fill="#FF0000"/><path d="M15 12V11H16V12H15Z" fill="#FF0000"/><path d="M8 12V10H9V12H8Z" fill="#FF0000"/><path d="M10 8V6H11V8H10Z" fill="#FF0000"/>',
            name: "CCCe"
        });
        burnerNFT.addArt(1, placeholder);
        /// Hair
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<path d="M10 23V24H15V23H16V21H17V19H16V18H15V16H14V12H12V13H11V17H10V18H9V23H10Z" fill="#FFAA00"/><path d="M13 11V10H14V11H13Z" fill="#FFAA00"/><path d="M15 15V13H16V15H15Z" fill="#FFAA00"/><path d="M9 15V14H10V15H9Z" fill="#FFAA00"/><path d="M12 9V8H13V9H12Z" fill="#FFAA00"/><path d="M13 7V6H14V7H13Z" fill="#FFAA00"/><path d="M10 12V11H11V12H10Z" fill="#FFAA00"/>',
            name: "DDDe"
        });
        burnerNFT.addArt(2, placeholder);
        /// Eyes
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<path d="M15 10H16V11H15V10Z" fill="#FFD84C"/><path d="M15 12H16V13H15V12Z" fill="#FFD84C"/><path d="M15 5H16V6H15V5Z" fill="#FFD84C"/><path d="M11 8H12V9H11V8Z" fill="#FFD84C"/><path d="M10 23V22H9V20H8V18H9V17H10V14H11V12H12V11H13V9H14V13H15V14H16V17H17V21H16V22H15V23H10ZM12 19H11V20H12V21H15V20H12V19Z" fill="#FFD84C"/>',
            name: "FFFe"
        });
        burnerNFT.addArt(3, placeholder);
        /// Mouth
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<path d="M7 15V18H13V15H14V18H20V12H14V14H13V12H7V14H4V17H5V15H7Z" fill="#B0B0B0"/><rect x="10" y="13" width="2" height="4" fill="black"/><rect x="17" y="13" width="2" height="4" fill="black"/><path d="M10 13H8V17H10V15H11V14H10V13Z" fill="white"/><path d="M17 13H15V17H17V15H18V14H17V13Z" fill="white"/>',
            name: "HHHe"
        });
        burnerNFT.addArt(4, placeholder);
    }
}
