// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Base64} from "@openzeppelin/utils/Base64.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @title  Lucky Ghouls Art
/// @notice On-chain art module, same interface as PotRaiderArt. Every token renders the ghoul from
///         src/assets/luckyghoul.svg on a background color derived from its tokenId (same hue scheme as PotRaiderArt).
contract LuckyGhoulsArt {
    using Strings for uint256;

    /// @notice Prefix for token names, e.g. "Ghoul" renders as "Ghoul #7"
    string public tokenNamePrefix;

    constructor(string memory _tokenNamePrefix) {
        tokenNamePrefix = _tokenNamePrefix;
    }

    function generateTokenURI(uint256 tokenId) external view returns (string memory) {
        string memory svg = generateSVG(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        tokenNamePrefix,
                        " #",
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

        // The mouth, nose and eye cutouts are filled with the background color so they read as holes in the head
        return string(
            abi.encodePacked(
                '<svg width="480" height="480" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="48" height="48" fill="',
                backgroundColor,
                '"/><path d="M19 9H24H29V10H31V11H32V10H33V9H34V6H35H36V7H37V9H38V13H37V15H36V18H37V19H38V18H39V17H40H41V23H40V26H39V28H38V29.5H37V31H35V30H34V31V32H33V34H32V37H31V38H30V39H29V41H28V42H27V43H21V42H20V41H19V39H18V38H17V37H16V34H15V32H14V30H13V31H11V30H10V28H9V26H8V23H7V17H8H9V18H10V19H11V18H12V15H11V13H10V9H11V7H12V6H14V9H15V10H16V11H17V10H19V9Z" fill="white"/><path d="M18 30H19V31H20H21V32H22V31H23V32H24H25V31H26V32H27V31H28H29V30H30V29H34V30H32V31H31V34H30V36H29V37H28V38H20V37H19V36H18V34H17V31H16V30H14V29H18V30Z" fill="',
                backgroundColor,
                '"/><path d="M23 26V25H25V26H26V29H25V28H23V29H22V26H23Z" fill="',
                backgroundColor,
                '"/><path d="M19 31H20V34H19V31Z" fill="white"/><path d="M28 31H29V34H28V31Z" fill="white"/><path d="M19 31H20V33H19V31Z" fill="white"/><path d="M28 31H29V33H28V31Z" fill="white"/><path d="M20 36H21V38H20V36Z" fill="white"/><path d="M22 37H26V38H22V37Z" fill="white"/><path d="M27 36H28V38H27V36Z" fill="white"/><path d="M21.006 31.994L22.006 32.006L21.994 33.006L20.994 32.994L21.006 31.994Z" fill="white"/><path d="M23 32H25V33H23V32Z" fill="white"/><path d="M24 32H25V33H24V32Z" fill="white"/><path d="M20 37H21V38H20V37Z" fill="white"/><path d="M23 37H25V38H23V37Z" fill="white"/><path d="M27 37H28V38H27V37Z" fill="white"/><path d="M26 32H27V33H26V32Z" fill="white"/><path d="M13 24V20H14V19H15V18H16V17H20V18H21V19H22V20H23V24H22V25H21V26H20V27H16V26H15V25H14V24H13Z" fill="',
                backgroundColor,
                '"/><rect x="17" y="21" width="1" height="1" fill="white"/><path d="M25 24V20H26V19H27V18H28V17H32V18H33V19H34V20H35V24H34V25H33V26H32V27H28V26H27V25H26V24H25Z" fill="',
                backgroundColor,
                '"/><rect x="29" y="21" width="1" height="1" fill="white"/></svg>'
            )
        );
    }

    function _clamp(uint256 value) internal pure returns (uint8) {
        return value > 255 ? 255 : uint8(value);
    }

    function getHueRGB(uint256 seed) internal pure returns (uint8 r, uint8 g, uint8 b) {
        // Use a better seed to ensure more variation
        uint256 hue = (seed * 137) % 360; // Use a prime number multiplier for better distribution
        uint256 saturation = 80 + (seed % 20); // 80-100% saturation
        uint256 lightness = 50 + (seed % 20); // 50-70% lightness

        // Convert HSL to RGB using a simpler approach
        uint256 c = (saturation * 255) / 100;
        uint256 m = (lightness * 255) / 100 - (c / 2);

        // Calculate which sextant of the color wheel we're in
        uint256 sextant = hue / 60;
        uint256 remainder = hue % 60;

        // Calculate the intermediate value
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
