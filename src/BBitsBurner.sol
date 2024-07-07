// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IV2Router} from "./interfaces/uniswap/IV2Router.sol";
import {IV3Router} from "./interfaces/uniswap/IV3Router.sol";
import {IBBitsBurner} from "./interfaces/IBBitsBurner.sol";

/// @title  Based Bits Burner
/// @notice This contract integrates with both Uniswap V2 and V3 to provide burning functionality for the
///         Based Bits fungible ERC20 token. The owner has exclusive permission to modify the swap parameters.
contract BBitsBurner is ReentrancyGuard, Ownable, IBBitsBurner {
    /// @notice dEaD address.
    address public constant dead = 0x000000000000000000000000000000000000dEaD;

    /// @notice Wrapped Ether.
    /// @dev    Infinite approval to all routers.
    IERC20 public immutable WETH;

    /// @notice Based Bits fungible token.
    IERC20 public immutable BBITS;

    /// @notice Uniswap V2 router.
    IV2Router public immutable uniV2Router;

    /// @notice Uniswap V3 router.
    IV3Router public immutable uniV3Router;

    /// @notice Swap parameters for the router
    /// @dev    uint8 pool
    ///         uint24 fee
    SwapParams public swapParams;

    constructor(
        address _owner,
        IERC20 _WETH,
        IERC20 _BBITS,
        IV2Router _uniV2Router,
        IV3Router _uniV3Router
    ) Ownable(_owner) {
        WETH = _WETH;
        BBITS = _BBITS;
        uniV2Router = _uniV2Router;
        uniV3Router = _uniV3Router;
        WETH.approve(address(uniV2Router), ~uint256(0));
        WETH.approve(address(uniV3Router), ~uint256(0));
        swapParams = SwapParams({
            pool: 3,
            fee: 3000
        });
    }

    receive() external payable {}

    /// @notice This function allows anyone to buy and burn BBITS tokens from Uniswap via the defined router.
    /// @param  _minAmountBurned defines the minimum number of BBITS tokens to be burned.
    /// @dev    Some ETH must be passed to make the purchase.
    function burn(uint256 _minAmountBurned) external payable nonReentrant {
        if (msg.value == 0) revert BuyZero();
        (bool success,) = address(WETH).call{value: address(this).balance}("");
        if (!success) revert WETHDepositFailed();
        swap(WETH.balanceOf(address(this)), _minAmountBurned);
    }

    /// @notice This functiona allows the owner to modify the Uniswap router used.
    /// @param  _newSwapParams is used to set the new swap parameters. Care must be taken with regard to the
    ///         fee parameter if setting a V3 pool. Moreover, only pool types of 2 or 3 are valid.
    function setSwapParams(SwapParams calldata _newSwapParams) external onlyOwner {
        if (_newSwapParams.pool != 2 && _newSwapParams.pool != 3) revert InValidPoolParams();
        swapParams = _newSwapParams;
    }

    function swap(uint256 _amountIn, uint256 _amountOut) internal {
        if (swapParams.pool == 2) {
            address[] memory path = new address[](2);
            path[0] = address(WETH);
            path[1] = address(BBITS);
            uniV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                _amountIn,
                _amountOut,
                path,
                dead,
                block.timestamp
            );
        } else {
            IV3Router.ExactInputSingleParams memory params = IV3Router.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: address(BBITS),
                fee: swapParams.fee,
                recipient: dead,
                amountIn: _amountIn,
                amountOutMinimum: _amountOut,
                sqrtPriceLimitX96: 0
            });
            uniV3Router.exactInputSingle(params);
        }
    }
}