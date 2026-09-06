// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Base64} from "@openzeppelin/utils/Base64.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @title  Lucky Ghouls Art
/// @notice Static, per-token on-chain art module. Same interface as PotRaiderArt; the image does not change with
///         treasury size. The SVG body is a placeholder borrowed from PotRaiderArt until the Pixel Imp art lands.
/// TODO: replace the SVG body below with the final Pixel Imp mascot art.
contract LuckyGhoulsArt {
    using Strings for uint256;

    function generateTokenURI(uint256 tokenId) external pure returns (string memory) {
        string memory svg = generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Ghoul #',
                        tokenId.toString(),
                        '", "description": "Every night the Cauldron buys Megapot tickets on behalf of the Lucky Ghouls. Each Ghoul can break the pact at any time to redeem its share of the Cauldron.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function generateSVG(uint256 tokenId) public pure returns (string memory) {
        (uint8 r, uint8 g, uint8 b) = getHueRGB(tokenId);

        string memory backgroundColor = string(
            abi.encodePacked("rgb(", uint256(r).toString(), ",", uint256(g).toString(), ",", uint256(b).toString(), ")")
        );

        return string(
            abi.encodePacked(
                '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="',
                backgroundColor,
                '"/><rect width="48" height="48" fill="black" opacity="0.8"/>',
                _body(),
                "</svg>"
            )
        );
    }

    /// @dev Placeholder body (PotRaider imp). Split out so the final art can be dropped in without touching the wrapper.
    function _body() internal pure returns (string memory) {
        return '<path d="M15 32H16V37H17V34H18V37H19V34H20V37H21V34H22V37H23V34H24V37H25V34H26V37H27V34H28V36H29V34H30V30H31V31H32V29H33V32H32V36H31V37H30V38H29V39H28V40H16V39H15V32Z" fill="white"/><path d="M34 29V28H32V29H30V28H28V30H27V31H26V30H25V31H24V30H23V31H22V30H21V31H20V30H19V31H18V30H17V31H16V30H15V31H14V30H13V28H11V27H10V24H11V15H12V13H13V11H14V10H15V9H16V8H18V7H29V8H31V9H33V10H34V11H35V12H36V14H37V16H38V25H37V27H36V28H35V29H34Z" fill="white"/><path d="M21 24V27H20V26H19V27H18V24H19V23H20V24H21Z" fill="#1E1E1E"/><path d="M21 23V19H22V18H23V17H24V16H28V17H29V18H30V19H31V24H30V25H29V26H24V25H23V24H22V23H21Z" fill="black"/><path d="M23 18H24V17H28V18H29V19H30V23H29V24H28V25H24V24H23V23H22V19H23V18Z" fill="#8BE24F"/><path d="M24 18H28V19H24V18Z" fill="#3E8A12"/><path d="M24 23H28V24H24V23Z" fill="#3E8A12"/><path d="M23 19H24V23H23V19Z" fill="#3E8A12"/><path d="M28 19H29V23H28V19Z" fill="#3E8A12"/><path d="M25 20H27V22H25V20Z" fill="#3E8A12"/><rect x="25" y="20" width="1" height="1" fill="white"/><path d="M8 23V19H9V18H10V17H11V16H15V17H16V18H17V19H18V24H17V25H16V26H11V25H10V24H9V23H8Z" fill="black"/><path d="M10 18H11V17H15V18H16V19H17V23H16V24H15V25H11V24H10V23H9V19H10V18Z" fill="#8BE24F"/><path d="M11 18H15V19H11V18Z" fill="#3E8A12"/><path d="M11 23H15V24H11V23Z" fill="#3E8A12"/><path d="M10 19H11V23H10V19Z" fill="#3E8A12"/><path d="M15 19H16V23H15V19Z" fill="#3E8A12"/><path d="M12 20H14V22H12V20Z" fill="#3E8A12"/><rect x="12" y="20" width="1" height="1" fill="white"/>';
    }

    function _clamp(uint256 value) internal pure returns (uint8) {
        return value > 255 ? 255 : uint8(value);
    }

    function getHueRGB(uint256 seed) internal pure returns (uint8 r, uint8 g, uint8 b) {
        uint256 hue = (seed * 137) % 360;
        uint256 saturation = 80 + (seed % 20);
        uint256 lightness = 50 + (seed % 20);

        uint256 c = (saturation * 255) / 100;
        uint256 m = (lightness * 255) / 100 - (c / 2);

        uint256 sextant = hue / 60;
        uint256 remainder = hue % 60;
        uint256 x = (c * (60 - remainder)) / 60;

        if (sextant == 0) {
            return (_clamp(c + m), _clamp(x + m), _clamp(m));
        } else if (sextant == 1) {
            return (_clamp(x + m), _clamp(c + m), _clamp(m));
        } else if (sextant == 2) {
            return (_clamp(m), _clamp(c + m), _clamp(x + m));
        } else if (sextant == 3) {
            return (_clamp(m), _clamp(x + m), _clamp(c + m));
        } else if (sextant == 4) {
            return (_clamp(x + m), _clamp(m), _clamp(c + m));
        } else {
            return (_clamp(c + m), _clamp(m), _clamp(x + m));
        }
    }
}
