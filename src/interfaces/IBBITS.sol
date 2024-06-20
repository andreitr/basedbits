// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IBBITS {
    error DepositZero();
    error PartialRedemptionDisallowed();
    error IndicesMustEqualNumberToBeExchanged();
    error IndicesMustBeMonotonicallyDecreasing();
    error IndexOutOfBounds();
}