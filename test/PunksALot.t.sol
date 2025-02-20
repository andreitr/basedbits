// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, Punkalot, BBitsCheckIn, BBitsBurner, console} from "@test/utils/BBitsTestUtils.sol";
import {IPunksALot} from "@src/interfaces/IPunksALot.sol";
import {Reverter} from "@test/utils/Reverter.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

/// @dev forge test --match-contract PunksALotTest -vvv
contract PunksALotTest is BBitsTestUtils, IPunksALot {
    function setUp() public override {
        forkBase();

        user0 = address(100);
        user1 = address(200);

        vm.deal(owner, 100e18);
        vm.deal(user0, 100e18);
        vm.deal(user1, 100e18);

        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
        checkIn = BBitsCheckIn(0xE842537260634175891925F058498F9099C102eB);
        punksALot = new Punkalot(owner, user0, address(burner), address(checkIn));
        addArt();

        unpauseLegacyCheckin();

        vm.startPrank(owner);
        basedBits.transferFrom(owner, user0, ownerTokenIds[0]);
        basedBits.transferFrom(owner, user1, ownerTokenIds[1]);
        vm.stopPrank();
    }

    /// SETUP ///

    function testInit() public view {
        assertEq(address(punksALot.burner()), address(burner));
        assertEq(address(punksALot.checkIn()), address(checkIn));
        assertEq(punksALot.artist(), user0);
        assertEq(punksALot.owner(), owner);
        assertEq(punksALot.burnPercentage(), 5000);
        assertEq(punksALot.totalSupply(), 0);
        assertEq(punksALot.supplyCap(), 1000);
        assertEq(punksALot.mintFee(), 0.0015 ether);
    }

    /// MINT ///

    function testMintFailureConditions() public prank(owner) {
        /// InsufficientETHPaid
        vm.expectRevert(InsufficientETHPaid.selector);
        punksALot.mint();

        /// CapExceeded
        for (uint256 i; i < 1000; i++) {
            punksALot.mint{value: 0.0015 ether}();
        }

        assertEq(punksALot.totalSupply(), 1000);
        vm.expectRevert(CapExceeded.selector);
        punksALot.mint{value: 0.0015 ether}();
    }

    function testMintSuccessConditions() public prank(user1) {
        assertEq(punksALot.totalSupply(), 0);
        assertEq(punksALot.balanceOf(user1), 0);
        uint256 artistBalanceBeforeMint = user0.balance;

        punksALot.mint{value: 0.0015 ether}();

        assertEq(punksALot.totalSupply(), 1);
        assertEq(punksALot.balanceOf(user1), 1);
        assertEq(
            user0.balance, artistBalanceBeforeMint + ((0.0015 ether * (10_000 - punksALot.burnPercentage()) / 10_000))
        );
    }

    function testUserMintPrice() public prank(owner) {
        uint256 mintFee = punksALot.mintFee();
        assertEq(punksALot.userMintPrice(user1), mintFee);

        /// 50% discount
        setCheckInStreak(user0, 50);
        assertEq(punksALot.userMintPrice(user0), mintFee - ((mintFee * 50) / 100));

        /// 90% discount
        setCheckInStreak(user1, 100);
        assertEq(punksALot.userMintPrice(user1), mintFee - ((mintFee * 90) / 100));

        /// Discount Number Exceeded
        vm.stopPrank();
        vm.startPrank(user1);

        punksALot.mint{value: 0.00015 ether}();
        punksALot.mint{value: 0.00015 ether}();
        punksALot.mint{value: 0.00015 ether}();
        assertEq(punksALot.userMintPrice(user1), mintFee);
    }

    /// OWNER ///

    function testSetBurnPercentage() public prank(owner) {
        assertEq(punksALot.burnPercentage(), 5000);

        /// Invalid percentage
        vm.expectRevert(InvalidPercentage.selector);
        punksALot.setBurnPercentage(10_001);

        /// Set
        punksALot.setBurnPercentage(10_000);
        assertEq(punksALot.burnPercentage(), 10_000);
    }

    /// ART ///

    function testSetArt() public prank(user1) {
        punksALot.mint{value: 0.0015 ether}();

        /// Not NFT Owner
        vm.stopPrank();
        vm.startPrank(user0);

        vm.expectRevert(NotNFTOwner.selector);
        punksALot.setArt(0);

        vm.stopPrank();
        vm.startPrank(user1);

        /// Set art
        string memory image0 = punksALot.tokenURI(0);
        string memory image1 = punksALot.tokenURI(0);
        while (keccak256(bytes(image0)) == keccak256(bytes(image1))) {
            vm.warp(block.timestamp + 1);
            punksALot.setArt(0);
            image1 = punksALot.tokenURI(0);
        }
        assertNotEq(image0, image1);
    }

    function testDraw() public prank(user1) {
        punksALot.mint{value: 0.0015 ether}();
        string memory image = punksALot.tokenURI(0);
        image;
        console.log(image);
    }

    function addArt() internal override prank(owner) {
        /// Load some art
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](2);
        /// Background
        placeholder[0] = IPunksALot.NamedBytes({core: '<rect width="24" height="24" fill="#DBAEB4"/>', name: "Pink"});
        placeholder[1] = IPunksALot.NamedBytes({core: '<rect width="24" height="24" fill="#B9B9B7"/>', name: "Gray"});
        punksALot.addArt(0, placeholder);
        /// Bodies
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M7 15V24H10V21H16V6H7V12H6V15H7Z" fill="#53A3FC"/><path d="M6 15H7V24H6V15Z" fill="#3B7AFF"/><path d="M5 12H6V15H5V12Z" fill="#3B7AFF"/><path d="M6 6H7V12H6V6Z" fill="#3B7AFF"/><path d="M7 5H16V6H7V5Z" fill="#3B7AFF"/><path d="M16 6H17V21H16V6Z" fill="#3B7AFF"/><path d="M9 21H16V22H9V21Z" fill="#3B7AFF"/><path d="M8 20H9V21H8V20Z" fill="#3B7AFF"/><path d="M10 22H11V24H10V22Z" fill="#3B7AFF"/><path d="M12 15H15V16H12V15Z" fill="#3B7AFF"/><path d="M7 7H8V9H7V7Z" fill="#82BCFC"/><path d="M8 6H9V7H8V6Z" fill="#82BCFC"/>',
            name: "Based Punk"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path d="M7 15V24H10V21H16V6H7V12H6V15H7Z" fill="#53A3FC"/><path d="M6 15H7V24H6V15Z" fill="#3B7AFF"/><path d="M5 12H6V15H5V12Z" fill="#3B7AFF"/><path d="M6 6H7V12H6V6Z" fill="#3B7AFF"/><path d="M7 5H16V6H7V5Z" fill="#3B7AFF"/><path d="M16 6H17V21H16V6Z" fill="#3B7AFF"/><path d="M9 21H16V22H9V21Z" fill="#3B7AFF"/><path d="M8 20H9V21H8V20Z" fill="#3B7AFF"/><path d="M10 22H11V24H10V22Z" fill="#3B7AFF"/><path d="M12 15H15V16H12V15Z" fill="#3B7AFF"/><path d="M7 7H8V9H7V7Z" fill="#82BCFC"/><path d="M8 6H9V7H8V6Z" fill="#82BCFC"/>',
            name: "Based Punk"
        });
        punksALot.addArt(1, placeholder);
        /// Heads
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M5 10H6V9H12V8H13V9H14V8H15V9H18V6H17V5H16V4H7V5H6V6H5V10Z" fill="#303135"/><path d="M12 5H13V6H12V5Z" fill="#52535A"/><path d="M6 3H7V4H6V3Z" fill="#303135"/><path d="M15 5H16V6H15V5Z" fill="#52535A"/><path d="M13 6H14V8H13V6Z" fill="#52535A"/><path d="M16 6H17V8H16V6Z" fill="#52535A"/>',
            name: "Bowl Cut"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M18 10H2V9H6V6H7V5H8V4H15V5H16V6H17V7H18V10ZM15 9H12V7H13V6H14V7H15V9Z" fill="#303135"/>',
            name: "Cap Back"
        });
        punksALot.addArt(2, placeholder);
        /// Mouth
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M11 19V18H17V17H18V21H17V19H11Z" fill="#3B7AFF"/><path d="M10 17H11V18H10V17Z" fill="#3B7AFF"/><path d="M12 17H13V18H12V17Z" fill="#CEDFFB"/><path d="M16 17H17V18H16V17Z" fill="#CEDFFB"/><path d="M16 21H17V22H16V21Z" fill="#3B7AFF"/><path d="M16 19H17V21H16V19Z" fill="#53A3FC"/>',
            name: "Troll"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path d="M10 17H11V18H10V17Z" fill="#3B7AFF"/><path d="M11 18H14V19H11V18Z" fill="#3B7AFF"/>',
            name: "Regular Smile"
        });
        punksALot.addArt(3, placeholder);
        /// Eyes
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M11 13H8V14H12V12H11V13Z" fill="#3B7AFF"/><path d="M17 13H14V14H18V12H17V13Z" fill="#3B7AFF"/><path d="M9 12H11V13H9V12Z" fill="#303135"/><path d="M8 12H9V13H8V12Z" fill="#CEDFFB"/><path d="M14 12H15V13H14V12Z" fill="#CEDFFB"/><path d="M15 12H17V13H15V12Z" fill="#303135"/>',
            name: "Angry Squint"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path d="M14 14V13H17V12H14V11H18V14H14Z" fill="#3B7AFF"/><path d="M12 14V13H9V14H12Z" fill="#3B7AFF"/><path d="M9 12H12V11H9V12Z" fill="#3B7AFF"/><path d="M9 12H11V13H9V12Z" fill="#CEDFFB"/><path d="M14 12H16V13H14V12Z" fill="#CEDFFB"/><path d="M11 12H12V13H11V12Z" fill="#303135"/><path d="M16 12H17V13H16V12Z" fill="#303135"/>',
            name: "Side Eye"
        });
        punksALot.addArt(4, placeholder);
    }
}
