// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import {ERC20, IERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {BBitsBurnerNFT} from "@src/BBitsBurnerNFT.sol";
import {IBBitsBurnerNFT} from "@src/interfaces/IBBitsBurnerNFT.sol";

contract FixArt is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BBitsBurnerNFT burnerNFT = BBitsBurnerNFT(payable(0x904cc558503916D725fDb9c5E65D8C83ac72AeB9));

        uint256[] memory indices = new uint256[](1);
        indices[0] = 20;
        burnerNFT.removeArt(4, indices);

        IBBitsBurnerNFT.NamedBytes[] memory placeholder = new IBBitsBurnerNFT.NamedBytes[](1);
        placeholder[0] = IBBitsBurnerNFT.NamedBytes({
            core: '<path d="M7 15V18H13V15H14V18H20V12H14V14H13V12H7V14H4V17H5V15H7Z" fill="#FFFFFF" opacity="0.6" /><rect x="10" y="13" width="2" height="4" fill="black"/><rect x="17" y="13" width="2" height="4" fill="black"/><path d="M10 13H8V17H10V15H11V14H10V13Z" fill="white"/><path d="M17 13H15V17H17V15H18V14H17V13Z" fill="white"/>',
            name: "Cute Clear"
        });
        burnerNFT.addArt(4, placeholder);

        vm.stopBroadcast();
    }
}

contract GetPrice is Script {
    /// @dev Don't broadcast
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BBitsBurnerNFT burnerNFT = BBitsBurnerNFT(payable(0x904cc558503916D725fDb9c5E65D8C83ac72AeB9));
        uint256 price = burnerNFT.mintPriceInWETH();
        console.log("Price (wei): ", price);

        vm.stopBroadcast();
    }
}
