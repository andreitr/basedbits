// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPotRaider {
    event NFTExchanged(uint256 indexed tokenId, address indexed owner, uint256 ethAmount, uint256 usdcAmount);
    event LotteryTicketPurchased(uint256 indexed day, uint256 amount);
    event BurnPercentageUpdated(uint256 burnPercentage);
    event LotteryReferrerUpdated(address indexed newReferrer);
    event MintPriceUpdated(uint256 _mintPrice);
    event LotteryParticipationDaysUpdated(uint256 _lotteryParticipationDays);

    error QuantityZero();
    error MaxMintPerCallExceeded();
    error InsufficientPayment();
    error TransferFailed();
    error InvalidPercentage();
    error NotOwner();
    error NoTreasuryAvailable();
    error LotteryAlreadyPurchased();
    error InsufficientUSDCForTicket();
    error InsufficientTreasury();

    function lotteryReferrer() external view returns (address);
}
