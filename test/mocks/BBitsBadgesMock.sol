// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IBBitsBadges} from "../../src/interfaces/IBBitsBadges.sol";

contract BBitsBadgesMock is IBBitsBadges {

    mapping(address => mapping(uint256 => uint256)) public balances;
    string private _uri;

    function mint(address to, uint256 id) external {
        balances[to][id] += 1;
    }

    function setURI(string memory uri) external {
        _uri = uri;
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return balances[account][id];
    }
}
