// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IJackpot} from "@src/interfaces/megapot/IJackpot.sol";
import {BBitsBurner} from "@src/BBitsBurner.sol";
import {LuckyGhouls} from "@src/LuckyGhouls.sol";
import {LuckyGhoulsArt} from "@src/modules/LuckyGhoulsArt.sol";

/// @title  Test Ghouls deploy
/// @notice A short-lived dress rehearsal of LuckyGhouls on Base mainnet: same contract, same art, but the
///         treasury is spent over 10 purchase days and a mint costs the ETH equivalent of 1 USDC (quoted from
///         Uniswap at deploy time). Everything else (supply cap, mint burn share, treasury burn clock) is unchanged.
/// @dev    FOUNDRY_PROFILE=luckyghouls forge script script/luckyghouls/TestGhoulsDeploy.s.sol --rpc-url <BASE_RPC_URL> --broadcast
contract TestGhoulsDeploy is Script {
    LuckyGhouls public testGhouls;
    LuckyGhoulsArt public artContract;

    uint256 public constant PURCHASE_DAYS = 10;
    uint256 public constant MINT_PRICE_USDC = 1e6; // $1

    // Base mainnet
    BBitsBurner public burner = BBitsBurner(payable(0x1595409cbAEf3dD2485107fb1e328fA0fA505c10));
    IERC20 public WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 public USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IV3Router public uniV3Router = IV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);
    IV3Quoter public uniV3Quoter = IV3Quoter(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a);
    /// @dev Megapot V2 Jackpot
    IJackpot public lotteryContract = IJackpot(0x3bAe643002069dBCbcd62B1A4eb4C4A397d042a2);

    function run() external {
        // Quote $1 in ETH off-chain (before broadcasting) so the mint price tracks the current rate
        uint256 mintPrice = quoteMintPrice();
        console.log("Test Ghouls mint price (wei):", mintPrice);

        vm.startBroadcast();

        artContract = new LuckyGhoulsArt("Test Ghoul");

        testGhouls = new LuckyGhouls(
            "Test Ghouls",
            "TGHOUL",
            msg.sender,
            mintPrice,
            burner,
            WETH,
            USDC,
            uniV3Router,
            uniV3Quoter,
            lotteryContract,
            artContract
        );

        testGhouls.setTotalPurchaseDays(PURCHASE_DAYS);

        vm.stopBroadcast();
    }

    /// @notice ETH (wei) that 1 USDC buys on the 0.05% WETH/USDC pool right now
    function quoteMintPrice() public returns (uint256 mintPrice) {
        IV3Quoter.QuoteExactInputSingleParams memory params = IV3Quoter.QuoteExactInputSingleParams({
            tokenIn: address(USDC), tokenOut: address(WETH), amountIn: MINT_PRICE_USDC, fee: 500, sqrtPriceLimitX96: 0
        });
        (mintPrice,,,) = uniV3Quoter.quoteExactInputSingle(params);
        require(mintPrice > 0, "quote failed");
    }
}
