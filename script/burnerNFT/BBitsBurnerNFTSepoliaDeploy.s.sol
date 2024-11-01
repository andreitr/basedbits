// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {ERC20, IERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IV3Quoter} from "@src/interfaces/uniswap/IV3Quoter.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
import {BBitsBurnerNFT} from "@src/BBitsBurnerNFT.sol";
import {BBitsBurnerNFTArtInstall} from "@script/burnerNFT/BBitsBurnerNFTArtInstall.sol";

contract BBitsBurnerNFTSepoliaDeploy is Script, BBitsBurnerNFTArtInstall {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IERC20 bbits = new MockBBits();
        IV3Router uniV3Router = new MockUniV3Router();
        IV3Quoter uniV3Quoter = new MockUniV3Quoter();

        burnerNFT = new BBitsBurnerNFT(0x42e84F0bCe28696cF1D254F93DfDeaeEB6F0D67d, bbits, uniV3Router, uniV3Quoter);

        _addArt();
        burnerNFT.mint{value: 1e15}();

        vm.stopBroadcast();
    }
}

contract Mint is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BBitsBurnerNFT burnerNFT = BBitsBurnerNFT(payable(0xf863524E00Cc7dE7d01cD9A85f17b3deD58f0272));
        for (uint256 i; i < 20; i++) {
            burnerNFT.mint{value: 1e15}();
        }

        vm.stopBroadcast();
    }
}

contract MockBBits is ERC20 {
    constructor() ERC20("BBTIS", "BBITS") {}
}

contract MockUniV3Router is IV3Router {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        params;
        amountOut = 1e15;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn) {
        params;
        amountIn = 1e15;
    }
}

contract MockUniV3Quoter is IV3Quoter {
    function quoteExactOutputSingle(QuoteExactOutputSingleParams memory params)
        external
        pure
        returns (uint256 amountIn, uint160 sqrtPriceX96After, uint32 initializedTicksCrossed, uint256 gasEstimate)
    {
        params;
        amountIn = 1e15;
        sqrtPriceX96After = 0;
        initializedTicksCrossed = 0;
        gasEstimate = 0;
    }
}
