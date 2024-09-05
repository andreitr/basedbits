// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BBitsTestUtils, Reverter, BBitsBurner, IBBitsBurner, BBITS, IERC20, console} from "@test/utils/BBitsTestUtils.sol";
import {IV2Router, IV3Router} from "@src/BBitsBurner.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

contract BBitsBurnerTest is BBitsTestUtils, IBBitsBurner {
    IV2Router public uniV2Router;
    IV3Router public uniV3Router;

    function setUp() public override {
        forkBase();
        vm.deal(owner, 1e20);

        WETH = IERC20(0x4200000000000000000000000000000000000006);
        basedBits = ERC721(0x617978b8af11570c2dAb7c39163A8bdE1D282407);
        bbits = BBITS(0x553C1f87C2EF99CcA23b8A7fFaA629C8c2D27666);
        uniV2Router = IV2Router(0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24);
        uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);

        burner = new BBitsBurner(owner, WETH, bbits, uniV2Router, uniV3Router);

        /// Add a V2 pool
        vm.startPrank(owner);
        (bool success,) = address(WETH).call{value: 1e18}("");
        if (!success) revert();
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        basedBits.setApprovalForAll(address(bbits), true);
        bbits.exchangeNFTsForTokens(tokenIds);
        WETH.approve(address(uniV2Router), ~uint256(0));
        bbits.approve(address(uniV2Router), ~uint256(0));
        uniV2Router.addLiquidity(
            address(WETH), address(bbits), WETH.balanceOf(owner), bbits.balanceOf(owner), 0, 0, owner, block.timestamp
        );
        vm.stopPrank();
    }

    function testInit() public view {
        assertEq(burner.owner(), owner);
        assertEq(burner.dead(), address(0xdEaD));
        assertEq(address(burner.WETH()), address(WETH));
        assertEq(address(burner.BBITS()), address(bbits));
        assertEq(address(burner.uniV2Router()), address(uniV2Router));
        assertEq(address(burner.uniV3Router()), address(uniV3Router));
        (uint8 pool, uint24 fee) = burner.swapParams();
        assertEq(pool, 3);
        assertEq(fee, 3000);
        assertEq(WETH.allowance(address(burner), address(uniV2Router)), type(uint256).max);
        assertEq(WETH.allowance(address(burner), address(uniV3Router)), type(uint256).max);
    }

    /// FAILURE ///

    function testV2BuyandBurnFailureConditions() public prank(owner) {
        /// Change pool route
        SwapParams memory newSwapParams = SwapParams({pool: 2, fee: 0});
        burner.setSwapParams(newSwapParams);

        /// Buy zero
        vm.expectRevert(BuyZero.selector);
        burner.burn(0);

        /// WETH transfer fails
        Reverter reverter = new Reverter();
        WETH = IERC20(address(reverter));

        BBitsBurner cursedBurner = new BBitsBurner(owner, WETH, bbits, uniV2Router, uniV3Router);

        vm.expectRevert(WETHDepositFailed.selector);
        cursedBurner.burn{value: 1}(0);

        WETH = IERC20(0x4200000000000000000000000000000000000006);

        /// Slippage
        vm.expectRevert();
        burner.burn{value: 1}(1e36);
    }

    function testV3BuyandBurnFailureConditions() public prank(owner) {
        /// Buy zero
        vm.expectRevert(BuyZero.selector);
        burner.burn(0);

        /// WETH transfer fails
        Reverter reverter = new Reverter();
        WETH = IERC20(address(reverter));

        BBitsBurner cursedBurner = new BBitsBurner(owner, WETH, bbits, uniV2Router, uniV3Router);

        vm.expectRevert(WETHDepositFailed.selector);
        cursedBurner.burn{value: 1}(0);

        WETH = IERC20(0x4200000000000000000000000000000000000006);

        /// Slippage
        vm.expectRevert();
        burner.burn{value: 1}(1e36);
    }

    function testSetSwapParamsFailureConditions() public prank(owner) {
        SwapParams memory newSwapParams = SwapParams({pool: 4, fee: 0});
        vm.expectRevert(InValidPoolParams.selector);
        burner.setSwapParams(newSwapParams);
    }

    /// SUCCESS ///

    function testV2BuyandBurnSuccessConditions() public prank(owner) {
        /// Change pool route
        SwapParams memory newSwapParams = SwapParams({pool: 2, fee: 0});
        burner.setSwapParams(newSwapParams);

        uint256 deadBalanceBefore = bbits.balanceOf(burner.dead());

        burner.burn{value: 1e18}(0);

        assertGt(bbits.balanceOf(burner.dead()), deadBalanceBefore);
    }

    function testV3BuyandBurnSuccessConditions() public prank(owner) {
        uint256 deadBalanceBefore = bbits.balanceOf(burner.dead());

        burner.burn{value: 1e18}(0);

        assertGt(bbits.balanceOf(burner.dead()), deadBalanceBefore);
    }
}
