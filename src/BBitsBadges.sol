// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IBBitsBadges} from "./interfaces/IBBitsBadges.sol";
import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BBitsBadges is ERC1155, AccessControl, Ownable {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public contractURI = "https://basedbits.fun/api/badges";

    event ContractURIUpdated(string newURI, uint256 timestamp);

    constructor(address _owner) ERC1155("https://basedbits.fun/api/badges/{id}") Ownable(_owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(address to, uint256 id) external onlyRole(MINTER_ROLE) {
        _mint(to, id, 1, "");
    }

    function setURI(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(uri);
    }

    function updateContractURI(string memory newURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contractURI = newURI;
        emit ContractURIUpdated(newURI, block.timestamp);
    }
}
