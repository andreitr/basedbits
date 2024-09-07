// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBBMintRaffleNFT} from "@src/interfaces/IBBMintRaffleNFT.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";

/// @notice Module of the BBitsEmoji collection that handles the art.
abstract contract Filter8Art is Ownable, IBBMintRaffleNFT {
    /// @notice The storage for all art components
    /// @dev    Layout:
    ///         0: background
    ///         1: face
    ///         2: eyes
    ///         3: mouth
    ///         4: hair
    mapping(uint256 => NamedBytes[]) public metadata;

    /// @notice The metadata components for any given NFT.
    mapping(uint256 => Set) public metadataForTokenId;

    /// @notice The description for the collection.
    bytes public description =
        "Inspired by the oldest known emojis (Sharp PI-4000, 1994), Emoji Bits (Onchain Summer Edition) is a fully on-chain NFT collection featuring experimental minting and gamification mechanisms. Every 8 hours, a new Emoji Bit is born! 50% of mint proceeds are raffled off to one lucky winner, while the rest are used to burn BBITS tokens. More -> https://www.basedbits.fun/emojibits";

    /// @notice This function allows the owner to add art components to the metadata storage.
    /// @param  _array The mapping key to access the relevant array of components to be added.
    /// @param  _data An array of components to be added.
    function addArt(uint256 _array, NamedBytes[] calldata _data) external onlyOwner {
        if (!_isValidArray(_array)) revert InvalidArray();
        uint256 length = _data.length;
        if (length == 0) revert InputZero();
        for (uint256 i; i < length; ++i) {
            metadata[_array].push(_data[i]);
        }
    }

    /// @notice This function allows the owner to remove art components to the metadata storage.
    /// @param  _array The mapping key to access the relevant array of components to be removed.
    /// @param  _indices An array of indices to be removed.
    function removeArt(uint256 _array, uint256[] calldata _indices) external onlyOwner {
        if (!_isValidArray(_array)) revert InvalidArray();
        uint256 length = _indices.length;
        if (length == 0) revert InputZero();
        uint256 arrayLength;
        for (uint256 i; i < length; ++i) {
            arrayLength = metadata[_array].length;
            if (_indices[i] >= arrayLength) revert InvalidIndex();
            if ((i > 0) && (_indices[i - 1] <= _indices[i])) revert IndicesMustBeMonotonicallyDecreasing();
            metadata[_array][_indices[i]] = metadata[_array][arrayLength - 1];
            metadata[_array].pop();
        }
    }

    /// @notice This function allows the owner to set the art for any token Id.
    /// @param  _tokenIds An array of token Ids.
    function setArt(uint256[] calldata _tokenIds) external onlyOwner {
        uint256 length = _tokenIds.length;
        if (length == 0) revert InputZero();
        for (uint256 i; i < length; ++i) {
            _set(_tokenIds[i]);
        }
    }

    /// @notice This function allows the owner to set the art description for the collection.
    /// @param  _description The new art description.
    function setDescription(bytes calldata _description) external onlyOwner {
        description = _description;
    }

    /// INTERNALS ///

    function _isValidArray(uint256 _array) internal pure returns (bool) {
        return (_array > 4) ? false : true;
    }

    function _draw(uint256 _tokenId) internal view returns (string memory) {
        Set memory art = metadataForTokenId[_tokenId];
        NamedBytes memory background = metadata[0][art.background];
        NamedBytes memory face = metadata[1][art.face];
        NamedBytes memory eyes = metadata[2][art.eyes];
        NamedBytes memory mouth = metadata[3][art.mouth];
        NamedBytes memory hair = metadata[4][art.hair];

        bytes memory svgHTML = abi.encodePacked(
            '<svg width="420" height="420" viewBox="0 0 21 21" fill="none" xmlns="http://www.w3.org/2000/svg">',
            background.core,
            face.core,
            eyes.core,
            mouth.core,
            hair.core,
            "</svg>"
        );
        svgHTML = abi.encodePacked(
            '{"name": "Emoji Bit #',
            bytes(Strings.toString(_tokenId)),
            '", "description": "',
            description,
            '", "image": "data:image/svg+xml;base64,',
            Base64.encode(svgHTML),
            '"'
        );
        svgHTML = abi.encodePacked(
            svgHTML,
            ', "attributes": [{"trait_type": "Background", "value": "',
            background.name,
            '"}, {"trait_type": "Face", "value": "',
            face.name,
            '"}, {"trait_type": "Eyes", "value": "',
            eyes.name,
            '"}, {"trait_type": "Mouth", "value": "',
            mouth.name,
            '"}, {"trait_type": "Hair", "value": "',
            hair.name,
            '"}]}'
        );

        return string.concat("data:application/json;base64,", Base64.encode(svgHTML));
    }

    function _set(uint256 _tokenId) internal {
        uint256 seed = _getPseudoRandom(_tokenId, block.timestamp);
        Set memory newMetadataForTokenId = Set({
            background: _getPseudoRandom(seed, 0) % metadata[0].length,
            face: _getPseudoRandom(seed, 1) % metadata[1].length,
            eyes: _getPseudoRandom(seed, 2) % metadata[2].length,
            mouth: _getPseudoRandom(seed, 3) % metadata[3].length,
            hair: _getPseudoRandom(seed, 4) % metadata[4].length
        });
        metadataForTokenId[_tokenId] = newMetadataForTokenId;
    }

    function _getPseudoRandom(uint256 _seed, uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_seed, _salt)));
    }
}
