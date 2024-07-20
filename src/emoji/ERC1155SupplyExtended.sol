// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC1155Supply} from "@openzeppelin/token/ERC1155/extensions/ERC1155Supply.sol";

/// @notice Module of the BBitsEmoji collection that provides total balance functionality for ERC1155.
abstract contract ERC1155SupplyExtended is ERC1155Supply {
    mapping(address => uint256) private totalBalances;

    /// @notice This function returns the total number of NFTs owned across all token Ids.
    /// @param  account The account being queried.
    /// @return total The total number of NFTs owned across all token Ids.
    function totalBalanceOf(address account) public view returns (uint256 total) {
        total = totalBalances[account];
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);
        uint256 length = values.length;
        for (uint256 i; i < length; ++i) {
            uint256 value = values[i];
            if (from != address(0)) totalBalances[from] -= value;
            if (to != address(0)) totalBalances[to] += value;
        }
    }
}