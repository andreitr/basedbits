// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IBaseRace} from "@src/interfaces/IBaseRace.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

abstract contract BaseRaceArt is IBaseRace {
    string ja;

    function _draw(uint256 _tokenId) internal view returns (string memory) {
        _tokenId;
        return ja;
    }
}
