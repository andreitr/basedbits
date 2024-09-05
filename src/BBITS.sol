// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IBBITS} from "@src/interfaces/IBBITS.sol";

/// @title  Based Bits Fungible Token
/// @notice This contract allows Based Bits NFT holders to exchange their NFTs for a fungible ERC20 token
///         equivalent. The fungible tokens may also be exchanged back for NFTs, with the option of users
///         being able to decide which specific NFTs held by this contract are to be exchanged.
contract BBITS is IBBITS, ERC20, ReentrancyGuard {
    /// @notice Based Bits NFT collection.
    IERC721 public immutable collection;

    /// @notice The amount of tokens received for 1 NFT.
    uint256 public immutable conversionRate;

    /// @notice An array of NFT token Ids held by this contract.
    uint256[] public tokenIds;

    constructor(IERC721 _collection, uint256 _conversionRate) ERC20("Based Bits", "BBITS") {
        collection = _collection;
        conversionRate = _conversionRate * (10 ** decimals());
    }

    /// @notice This function allows users to exchange their NFTs for fungible tokens given the defined
    ///         conversion rate.
    /// @param  _tokenIds An array of Based Bits token Ids to exchange for fungible tokens.
    /// @dev    The user must grant this contract approval to move their NFTs.
    function exchangeNFTsForTokens(uint256[] calldata _tokenIds) external nonReentrant {
        uint256 length = _tokenIds.length;
        if (length == 0) revert DepositZero();
        for (uint256 i; i < length; i++) {
            collection.transferFrom(msg.sender, address(this), _tokenIds[i]);
            tokenIds.push(_tokenIds[i]);
            emit Deposit(msg.sender, _tokenIds[i]);
        }
        _mint(msg.sender, length * conversionRate);
    }

    /// @notice This function allows users to exchange their fungible BBITS tokens back to Based Bits NFTs.
    /// @param  _amount The amount of fungible tokens to exchange. This amount must be a multiple of the
    ///         conversion rate.
    function exchangeTokensForNFTs(uint256 _amount) external nonReentrant {
        if (_amount == 0) revert DepositZero();
        if (_amount % conversionRate != 0) revert PartialRedemptionDisallowed();
        _burn(msg.sender, _amount);
        uint256 length = _amount / conversionRate;
        for (uint256 i; i < length; i++) {
            collection.transferFrom(address(this), msg.sender, tokenIds[0]);
            emit Withdrawal(msg.sender, tokenIds[0]);
            tokenIds[0] = tokenIds[tokenIds.length - 1];
            tokenIds.pop();
        }
    }

    /// @notice This function allows users to exchange their fungible BBITS tokens back to Based Bits NFTs.
    ///         Users can specify which NFTs held by this contract get exchanged with the _indices input array.
    /// @param  _amount The amount of fungible tokens to exchange. This amount must be a multiple of the
    ///         conversion rate.
    /// @param  _indices An array of indices that specify which NFTs get exchanged. The indices correspond to
    ///         the position of the NFTs held by this contract as recorded in the tokenIds array, and not the
    ///         the token Ids of the NFTs themselves.
    /// @dev    Elements in this indices array must be monotonically decreasing.
    function exchangeTokensForSpecificNFTs(uint256 _amount, uint256[] calldata _indices) external nonReentrant {
        if (_amount == 0) revert DepositZero();
        if (_amount % conversionRate != 0) revert PartialRedemptionDisallowed();
        uint256 length = _amount / conversionRate;
        if (length != _indices.length) revert IndicesMustEqualNumberToBeExchanged();
        _burn(msg.sender, _amount);
        for (uint256 i; i < length; i++) {
            if ((i > 0) && (_indices[i - 1] <= _indices[i])) revert IndicesMustBeMonotonicallyDecreasing();
            collection.transferFrom(address(this), msg.sender, getTokenIdAtIndex(_indices[i]));
            emit Withdrawal(msg.sender, tokenIds[_indices[i]]);
            tokenIds[_indices[i]] = tokenIds[tokenIds.length - 1];
            tokenIds.pop();
        }
    }

    /// @notice This view function returns the number of Based Bits NFTs held by this contract.
    /// @return _count The number of Based Bits NFTs held by this contract.
    /// @dev    Any NFTs sent to this contract without using the exchange method will be lost forever, and not
    ///         included in this count.
    function count() public view returns (uint256 _count) {
        _count = tokenIds.length;
    }

    /// @notice This view function returns the token Id of the Based Bit NFT in any given index location in the
    ///         tokenIds array.
    /// @param  _index The index location to query.
    /// @return _tokenId The token Id that is held in the index location in the tokenIds array.
    function getTokenIdAtIndex(uint256 _index) public view returns (uint256 _tokenId) {
        if (_index >= tokenIds.length) revert IndexOutOfBounds();
        _tokenId = tokenIds[_index];
    }
}
