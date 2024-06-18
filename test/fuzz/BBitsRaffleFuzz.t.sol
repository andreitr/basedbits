// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    BBitsTestUtils,
    BBitsCheckIn,
    BBitsRaffle,
    console
} from "../utils/BBitsTestUtils.sol";
import {ERC721, IERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {IBBitsRaffle} from "../../src/interfaces/IBBitsRaffle.sol";

contract BBitsRaffleFuzz is BBitsTestUtils, IBBitsRaffle {
    function testFuzzDepositBasedBits(uint256 _length, address _sponsor) public {
        _length = bound(_length, 1, 20);
        vm.assume(_sponsor != address(0));
        vm.startPrank(_sponsor);

        (,bytes memory data) = address(basedBits).staticcall(abi.encodeWithSelector(bytes4(keccak256("nonce()"))));
        uint256 nonce = abi.decode(data, (uint256));
        (bool s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mintMany(address,uint256)")), _sponsor, _length));
        assert(s);

        uint256[] memory tokenIds;

        vm.expectRevert(DepositZero.selector);
        raffle.depositBasedBits(tokenIds);

        tokenIds = new uint256[](_length);

        for (uint256 i; i < _length; i++) {
            tokenIds[i] = nonce + i;
        }
        basedBits.setApprovalForAll(address(raffle), true);

        for (uint256 i; i < _length; i++) {
            vm.expectEmit(true, true, true, true);
            emit BasedBitsDeposited(_sponsor, tokenIds[i]);
        }
        raffle.depositBasedBits(tokenIds);

        assertEq(basedBits.balanceOf(address(raffle)), _length);
        for (uint256 i; i < _length; i++) {
            (uint256 tokenId, address sponsor) = raffle.prizes(i);
            assertEq(sponsor, _sponsor);
            assertEq(tokenId, tokenIds[i]);
        }

        vm.stopPrank();
    }

    function testFuzzEntries(uint256 _amount0, uint256 _amount1) public {
        /// Set up users
        address[10] memory users = [
            makeAddr("alpha"),
            makeAddr("beta"),
            makeAddr("gamma"),
            makeAddr("delta"),
            makeAddr("epsilon"),
            makeAddr("eta"),
            makeAddr("theta"),
            makeAddr("iota"),
            makeAddr("kappa"),
            makeAddr("lambda")
        ];

        bool s;
        (,bytes memory data) = address(basedBits).staticcall(abi.encodeWithSelector(bytes4(keccak256("nonce()"))));
        uint256 nonce = abi.decode(data, (uint256));

        _amount0 = bound(_amount0, 1, 10);
        for (uint256 b; b < _amount0; b++) {
            vm.startPrank(users[b]);

            (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mintMany(address,uint256)")), users[b], 10));
            assert(s);

            vm.deal(users[b], 1e19);
            checkIn.checkIn();

            nonce = nonce + 10;
            vm.stopPrank();
        }

        _amount1 = bound(_amount1, 0, 1e18);
        uint256 antiBotFee = raffle.antiBotFee();
        vm.assume(_amount1 != antiBotFee);
    
        (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), owner));
        assert(s);

        /// Set up raffle
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nonce++;
        basedBits.setApprovalForAll(address(raffle), true);
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();
        vm.stopPrank();

        uint256 totalEntries = raffle.getRaffleEntryNumber(1);
        uint256 paidEntries;

        /// Entries
        for (uint256 i; i < _amount0; i++) {
            vm.startPrank(users[i]);
            if (_amount1 % (i + 2) == 0) {
                raffle.newFreeEntry();
            } else {
                vm.expectRevert(MustPayAntiBotFee.selector);
                raffle.newPaidEntry{value: _amount1}();

                raffle.newPaidEntry{value: antiBotFee}();
                ++paidEntries;
            }
            vm.stopPrank();
        }

        assertEq(address(raffle).balance, paidEntries * antiBotFee);

        /// Settle
        vm.warp(block.timestamp + 1.01 days);
        vm.startPrank(users[_amount0 - 1]);

        vm.roll(block.number + 2);
        raffle.settleRaffle();
        vm.stopPrank();

        /// Checks
        
        assertEq(raffle.getRaffleEntryNumber(1), totalEntries + _amount0);
        assertEq(address(raffle).balance, 0);

        (, , address winner,) = raffle.idToRaffle(1);
        assertEq(basedBits.ownerOf(nonce - 1), winner);

        vm.expectRevert(NoBasedBitsToRaffle.selector);
        raffle.startNextRaffle();
    }

    function testFuzzSettleRaffle(uint256 _amount0, uint256 _amount1) public {
        /// Set up users
        address[10] memory users = [
            makeAddr("alpha"),
            makeAddr("beta"),
            makeAddr("gamma"),
            makeAddr("delta"),
            makeAddr("epsilon"),
            makeAddr("eta"),
            makeAddr("theta"),
            makeAddr("iota"),
            makeAddr("kappa"),
            makeAddr("lambda")
        ];

        bool s;
        (,bytes memory data) = address(basedBits).staticcall(abi.encodeWithSelector(bytes4(keccak256("nonce()"))));
        uint256 nonce = abi.decode(data, (uint256));

        _amount0 = bound(_amount0, 1, 10);

        for (uint256 b; b < _amount0; b++) {
            vm.deal(users[b], 1e19);
        }
        
        _amount1 = bound(_amount1, 0, 1e18);
        uint256 antiBotFee = raffle.antiBotFee();
        vm.assume(_amount1 != antiBotFee);

        (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), owner));
        assert(s);

        /// Set up raffle
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nonce++;
        basedBits.setApprovalForAll(address(raffle), true);
        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();
        vm.stopPrank();

        uint256 ownerBalanceBefore = address(owner).balance;
        uint256 deposits;

        /// Entries
        for (uint256 i; i < _amount0; i++) {
            vm.startPrank(users[i]);
            if (_amount1 % (i + 4) == 0) {
                vm.stopPrank();
                break;
            } else {
                vm.expectRevert(MustPayAntiBotFee.selector);
                raffle.newPaidEntry{value: _amount1}();

                raffle.newPaidEntry{value: antiBotFee}();
                ++deposits;
            }
            vm.stopPrank();
        }

        assertEq(address(raffle).balance, deposits * antiBotFee);

        /// Settle
        vm.warp(block.timestamp + 1.01 days);

        assertEq(address(raffle).balance, deposits * antiBotFee);

        vm.startPrank(users[0]);
        vm.roll(block.number + 2);
        raffle.settleRaffle();
        vm.stopPrank();

        (,, address winner,) = raffle.idToRaffle(1);
        if (winner == address(0)) {
            assertEq(address(raffle).balance, deposits * antiBotFee);
            assertEq(address(owner).balance, ownerBalanceBefore);
        } else {
            assertEq(address(raffle).balance, 0);
            assertEq(address(owner).balance, ownerBalanceBefore + deposits * antiBotFee);
        }
    }

    function testSendEther(uint256 _amount) public prank(owner) {
        _amount = bound(_amount, 0, 1e18);

        uint256 balanceBefore = address(raffle).balance;

        (bool s,) = address(raffle).call{value: _amount}("");
        require(s);

        assertEq(address(raffle).balance, balanceBefore + _amount);
    }

    function testReturnDeposits(uint256 _amount) public prank(owner) {
        _amount = bound(_amount, 21, 40);
        /// 21 or more deposits
        vm.stopPrank();
        vm.startPrank(user2);

        basedBits.setApprovalForAll(address(raffle), true);

        (,bytes memory data) = address(basedBits).staticcall(abi.encodeWithSelector(bytes4(keccak256("nonce()"))));
        uint256 nonce = abi.decode(data, (uint256));
        (bool s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mintMany(address,uint256)")), user2, _amount));
        assert(s);

        uint256[] memory tokenIds = new uint256[](_amount);
        for (uint256 i; i < _amount; i++) {
            tokenIds[i] = nonce + i;
        }
        raffle.depositBasedBits(tokenIds);
        vm.stopPrank();
        vm.startPrank(owner);
        raffle.setPaused(true);
        
        (uint256 _tokenId, address _sponsor) = raffle.prizes(0);
        assertEq(basedBits.ownerOf(_tokenId), address(raffle));
        assertEq(basedBits.balanceOf(address(raffle)), _amount);

        /// Returns 20, stills holds 1
        raffle.returnDeposits();

        (_tokenId, _sponsor) = raffle.prizes(0);
        assertEq(basedBits.ownerOf(_tokenId), address(raffle));
        assertEq(basedBits.balanceOf(address(raffle)), _amount - 20);
        assertEq(basedBits.balanceOf(user2), 20);

        raffle.returnDeposits();
        assertEq(basedBits.ownerOf(_tokenId), user2);
        assertEq(basedBits.balanceOf(address(raffle)), 0);
        assertEq(basedBits.balanceOf(user2), _amount);
    }

    function testCheckInTime(uint256 _amount) public prank(owner) {
        _amount = bound(_amount, 0, 2 days - 1);

        (,bytes memory data) = address(basedBits).staticcall(abi.encodeWithSelector(bytes4(keccak256("nonce()"))));
        uint256 nonce = abi.decode(data, (uint256));
        (bool s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), user0));
        assert(s);
        (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), user0));
        assert(s);
        (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), owner));
        assert(s);

        checkIn.checkIn();
        vm.stopPrank();
        vm.startPrank(user0);
        checkIn.checkIn();
        
        vm.warp(block.timestamp + _amount);

        basedBits.setApprovalForAll(address(raffle), true);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nonce;

        raffle.depositBasedBits(tokenIds);
        raffle.startNextRaffle();
        
        /// Valid free entry
        raffle.newFreeEntry();
        vm.stopPrank();
        vm.startPrank(owner);
    }
}
