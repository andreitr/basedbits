// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPotRaider {
    event NFTExchanged(uint256 indexed tokenId, address indexed owner, uint256 ethAmount, uint256 usdcAmount);
    event PercentagesUpdated(uint256 burnPercentage, uint256 artistPercentage);
    event LotteryTicketPurchased(uint256 indexed day, uint256 amount);
    event LotteryContractUpdated(address indexed newContract);
    event USDCContractUpdated(address indexed newContract);
    event UniswapQuoterUpdated(address indexed newQuoter);
    event LotteryReferrerUpdated(address indexed newReferrer);

    error InvalidPercentage();
    error TransferFailed();
    error LotteryNotConfigured();
    error LotteryAlreadyPurchased();
    error LotteryPeriodEnded();
    error InsufficientTreasury();
    error USDCNotConfigured();
    error InsufficientUSDCBalance();
    error InsufficientUSDCForTicket();
    error UniswapQuoterNotConfigured();
    error UniswapRouterNotConfigured();
    error QuoterCallFailed();
    error QuantityZero();
    error InsufficientPayment();
    error BurnTransferFailed();
    error ArtistTransferFailed();
    error NotOwner();
    error NoNFTsInCirculation();
    error NoTreasuryAvailable();
    error ExchangeTransferFailed();
    error WETHNotConfigured();
    error MaxMintPerCallExceeded();
}
