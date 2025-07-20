// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ILotteryContract} from "@src/PotRaider.sol";

contract MockLottery is ILotteryContract {
    uint256 public override lpPoolTotal;
    uint256 public override lastJackpotEndTime;
    uint256 public override roundDurationInSeconds;

    bool public withdrawCalled;
    address public purchaseReferrer;
    uint256 public purchaseValue;
    address public purchaseRecipient;

    constructor(uint256 _roundDurationInSeconds) {
        roundDurationInSeconds = _roundDurationInSeconds;
    }

    function purchaseTickets(address referrer, uint256 value, address recipient) external override {
        purchaseReferrer = referrer;
        purchaseValue = value;
        purchaseRecipient = recipient;
    }

    function withdrawWinnings() external override {
        withdrawCalled = true;
    }
}
