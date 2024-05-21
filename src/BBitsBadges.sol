//// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.25;
//
//import {ERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
//import {ERC1155Supply} from "lib/openzeppelin-contracts/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
//import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
//import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
//
//contract BBitsBadges is ERC1155, ERC1155Supply, AccessControl, Ownable {
//    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
//
//    constructor(string memory baseURI, address _initialOwner) ERC1155(baseURI) Ownable(_initialOwner) {
//        transferOwnership(_initialOwner);
//        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//        _grantRole(MINTER_ROLE, msg.sender);
//    }
//
//    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
//    internal
//    override(ERC1155, ERC1155Supply)
//    {
//        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
//    }
//
//    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
//        return super.supportsInterface(interfaceId);
//    }
//
//    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
//        _mint(to, id, amount, data);
//    }
//
//    function setURI(string memory newuri) external onlyOwner {
//        _setURI(newuri);
//    }
//
//    function uri(uint256 tokenId) public view override returns (string memory) {
//        return string(abi.encodePacked(super.uri(tokenId), tokenId));
//    }
//}
