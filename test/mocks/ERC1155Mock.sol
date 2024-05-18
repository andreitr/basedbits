// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC1155Mintable} from "../../src/interfaces/IERC1155Mintable.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract ERC1155Mock is IERC1155Mintable {
    mapping(address => mapping(uint256 => uint256)) public balances;

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external override {
        balances[to][id] += amount;
    }

    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return balances[account][id];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view override returns (uint256[] memory) {
        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balances[accounts[i]][ids[i]];
        }

        return batchBalances;
    }

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return interfaceId == type(IERC1155Mintable).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    // Implement other required methods as no-op
    function setApprovalForAll(address operator, bool approved) external override {}
    function isApprovedForAll(address account, address operator) external view override returns (bool) { return false; }
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) external override {}
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external override {}
}
