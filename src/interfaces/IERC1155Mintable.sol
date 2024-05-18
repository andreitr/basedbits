// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";

interface IERC1155Mintable is IERC1155 {
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external;
}
