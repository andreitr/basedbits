// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IRunningGame} from "@src/interfaces/IRunningGame.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Base64} from "@openzeppelin/utils/Base64.sol";
import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";

abstract contract RunningGameArt is IRunningGame {
    string ja;

    function _draw(uint256 _tokenId) internal view returns (string memory) {
        _tokenId;
        return ja;
    }
}
