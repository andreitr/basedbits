// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBBMintRaffleNFT} from "@src/interfaces/IBBMintRaffleNFT.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";

/// @notice Module for the Filter8 collection that handles the art.
abstract contract Filter8Art is Ownable, IBBMintRaffleNFT {
    /// @notice The storage for all art components
    /// @dev    Layout:
    ///         0: background
    ///         1: body
    ///         2: eyes
    ///         3: hair
    ///         4: mouth
    mapping(uint256 => NamedBytes[]) public metadata;

    /// @notice The metadata components for any given NFT.
    mapping(uint256 => Set) public metadataForTokenId;

    /// @notice The description for the collection.
    bytes public description =
        "Bit98 is a fully on-chain pixel art collection by filter8.eth. Inspired by the color aesthetics of Windows 98, the collection features a novel minting and gamification mechanism, with a new Bit98 generated every 4 hours. At the end of the minting period, a single-edition NFT will be raffled off to one of the minters. Only 512 Bit98s will ever exist! Mint at https://www.basedbits.fun";

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
        NamedBytes memory body = metadata[1][art.body];
        NamedBytes memory eyes = metadata[2][art.eyes];
        NamedBytes memory hair = metadata[3][art.hair];
        NamedBytes memory mouth = metadata[4][art.mouth];

        bytes memory svgHTML = abi.encodePacked(
            '<svg width="800" height="800" viewBox="0 0 800 800" fill="none" xmlns="http://www.w3.org/2000/svg">',
            background.core,
            body.core,
            eyes.core,
            hair.core,
            mouth.core,
            "</svg>"
        );
        svgHTML = abi.encodePacked(
            '{"name": "Bit98 #',
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
            '"}, {"trait_type": "Body", "value": "',
            body.name,
            '"}, {"trait_type": "Eyes", "value": "',
            eyes.name,
            '"}, {"trait_type": "Hair", "value": "',
            hair.name,
            '"}, {"trait_type": "Mouth", "value": "',
            mouth.name,
            '"}]}'
        );

        return string.concat("data:application/json;base64,", Base64.encode(svgHTML));
    }

    function _set(uint256 _tokenId) internal {
        uint256 seed = _getPseudoRandom(_tokenId, block.timestamp);
        Set memory newMetadataForTokenId = Set({
            background: _getPseudoRandom(seed, 0) % metadata[0].length,
            body: _getPseudoRandom(seed, 1) % metadata[1].length,
            eyes: _getPseudoRandom(seed, 2) % metadata[2].length,
            hair: _getPseudoRandom(seed, 3) % metadata[3].length,
            mouth: _getPseudoRandom(seed, 4) % metadata[4].length
        });
        metadataForTokenId[_tokenId] = newMetadataForTokenId;
    }

    function _getPseudoRandom(uint256 _seed, uint256 _salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(_seed, _salt)));
    }
}
