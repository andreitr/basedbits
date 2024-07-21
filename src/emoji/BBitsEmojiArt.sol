// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBBitsEmoji} from "../interfaces/IBBitsEmoji.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";

/// @notice Module of the BBitsEmoji collection that handles the art.
abstract contract BBitsEmojiArt is Ownable, IBBitsEmoji {
    /// @notice The storage for all art components
    /// @dev    Layout:
    ///         0: background1
    ///         1: background2
    ///         2: head
    ///         3: hair1
    ///         4: hair2
    ///         5: eyes1
    ///         6: eyes2
    ///         7: mouth1
    ///         8: mouth2
    mapping(uint256 => NamedBytes[]) public metadata;

    /// @notice The metadata components for any given NFT. 
    mapping(uint256 => Set) public metadataForTokenId;

    /// @notice This function allows the owner to add art components to the metadata storage.
    /// @param  _array The mapping key to access the relevant array of components to be added.
    /// @param  _data An array of components to be added.
    /// @dev    Ensure each component in the _data array belongs to the _array mapping key family.
    ///         Any art components added can not be removed!
    function addArt(uint256 _array, NamedBytes[] calldata _data) external onlyOwner {
        if (!_isValidArray(_array)) revert InvalidArray();
        uint256 length = _data.length;
        if (length == 0) revert InputZero();
        for (uint256 i; i < length; ++i) {
            metadata[_array].push(_data[i]);
        }
    }

    /// INTERNALS ///

    function _isValidArray(uint256 _array) internal pure returns (bool) {
        return (_array > 8) ? false : true;
    }
    
    /// @dev REMEMBER TO DOUBLE-CHECK METADATA AND ADD DESCRIPTION
    function _draw(uint256 _tokenId) internal view returns (string memory) {
        Set memory art = metadataForTokenId[_tokenId];
        NamedBytes memory background1 = metadata[0][art.background1];
        NamedBytes memory background2 = metadata[1][art.background2];
        NamedBytes memory head = metadata[2][art.head];
        NamedBytes memory hair1 = metadata[3][art.hair1];
        NamedBytes memory hair2 = metadata[4][art.hair2];
        NamedBytes memory eyes1 = metadata[5][art.eyes1];
        NamedBytes memory eyes2 = metadata[6][art.eyes2];
        NamedBytes memory mouth1 = metadata[7][art.mouth1];
        NamedBytes memory mouth2 = metadata[8][art.mouth2];

        bytes memory svgHTML = abi.encodePacked(
            '<svg width="1024" height="1024" viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="1024" height="1024" fill="#D9D9D9"/>',
            background1.core,
            background2.core,
            head.core,
            hair1.core,
            hair2.core,
            eyes1.core,
            eyes2.core,
            mouth1.core,
            mouth2.core,
            '</svg>'
        );
        svgHTML = abi.encodePacked(
            '{"name": "Based Bits Emoji #',
            bytes(Strings.toString(_tokenId)), 
            '", "description": "??????????????????????", "image": "data:image/svg+xml;base64,', 
            Base64.encode(svgHTML), 
            '"'
        );
        svgHTML = abi.encodePacked(
            svgHTML,
            ', "attributes": [{"trait_type": "Background 1", "value": "',
            background1.name,
            '"}, {"trait_type": "Background 2", "value": "',
            background2.name,
            '"}, {"trait_type": "Head", "value": "',
            head.name,
            '"}, {"trait_type": "Hair 1", "value": "',
            hair1.name
        );
        svgHTML = abi.encodePacked(
            svgHTML,
            '"}, {"trait_type": "Hair 2", "value": "',
            hair2.name,
            '"}, {"trait_type": "Eyes 1", "value": "',
            eyes1.name,
            '"}, {"trait_type": "Eyes 2", "value": "',
            eyes2.name,
            '"}, {"trait_type": "Mouth 1", "value": "',
            mouth1.name,
            '"}, {"trait_type": "Mouth 2", "value": "',
            mouth2.name,
            '"}]}'
        );

        return string.concat('data:application/json;base64,', Base64.encode(svgHTML));
    }

    function _set(uint256 _tokenId) internal {
        uint256 seed = _getPseudoRandom(_tokenId, block.timestamp);
        Set memory newMetadataForTokenId = Set({
            background1: _getPseudoRandom(seed, 0) % metadata[0].length,
            background2: _getPseudoRandom(seed, 1) % metadata[1].length,
            head:        _getPseudoRandom(seed, 2) % metadata[2].length,
            hair1:       _getPseudoRandom(seed, 3) % metadata[3].length,
            hair2:       _getPseudoRandom(seed, 4) % metadata[4].length,
            eyes1:       _getPseudoRandom(seed, 5) % metadata[5].length,
            eyes2:       _getPseudoRandom(seed, 6) % metadata[6].length,
            mouth1:      _getPseudoRandom(seed, 7) % metadata[7].length,
            mouth2:      _getPseudoRandom(seed, 8) % metadata[8].length
        });
        metadataForTokenId[_tokenId] = newMetadataForTokenId;
    }

    function _getPseudoRandom(uint256 _seed, uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_seed, _salt)));
    }
}