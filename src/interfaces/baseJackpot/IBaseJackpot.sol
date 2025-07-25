// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBaseJackpot {
    function purchaseTickets(address referrer, uint256 value, address recipient) external;
    function withdrawWinnings() external;
    function lpPoolTotal() external view returns (uint256);
    function lastJackpotEndTime() external view returns (uint256);
    function roundDurationInSeconds() external view returns (uint256);
}
