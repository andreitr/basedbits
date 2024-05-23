// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IBBitsBadges} from "./interfaces/IBBitsBadges.sol";
import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "../lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract BBitsBadges is ERC1155, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory baseURI, address _minter, address _owner) ERC1155(baseURI)  {
        _grantRole(MINTER_ROLE, _minter);
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
}
