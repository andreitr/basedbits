// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {IV3Pool} from "@src/interfaces/uniswap/IV3Pool.sol";
import {IV3Router} from "@src/interfaces/uniswap/IV3Router.sol";
/// @dev need to handle on-chain art also

contract BBitsBurnerNFT is ERC721, ReentrancyGuard, Ownable {
    /// @notice Based Bits fungible token.
    IERC20 public immutable BBITS;

    /// @notice Uniswap V3 router.
    IV3Router public immutable uniV3Router;

    /// @notice Uniswap V3 BBITS pool.
    IV3Pool public immutable uniV3Pool;

    constructor(address _owner, IERC20 _BBITS, IV3Router _router, IV3Pool _pool)
        Ownable(_owner)
        ERC721("Based Bits Burner NFT", "BBB")
    {
        BBITS = _BBITS;
        uniV3Router = _router;
        uniV3Pool = _pool;
    }

    /// Router can be used to buy the token with a fixed amount out

    function mint() external payable nonReentrant {
        /// Must pass enough value to mint an NFT
    }

    /// Pool can be used to get an estimate for price
    /// Doesn't work atm
    function getPrice() public view returns (uint256 price) {
        (uint160 sqrtPriceX96,,,,,,) = uniV3Pool.slot0();

        price = (uint256(sqrtPriceX96) * uint256(sqrtPriceX96)) / (2 ** 192);

        /*
        function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
        */
    }
}
