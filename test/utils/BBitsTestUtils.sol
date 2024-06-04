// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";

// Core
import {BBitsBadges} from "../../src/BBitsBadges.sol";
import {BBitsCheckIn} from "../../src/BBitsCheckIn.sol";
import {BBitsSocial} from "../../src/BBitsSocial.sol";
import {BBitsRaffle} from "../../src/BBitsRaffle.sol";

// Minters
import {BBitsBadge7Day} from "../../src/minters/BBitsBadge7Day.sol";
import {BBitsBadgeFirstClick} from "../../src/minters/BBitsBadgeFirstClick.sol";
import {BBitsBadgeBearPunk} from "../../src/minters/BBitsBadgeBearPunk.sol";

// Mocks
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {MockERC721} from "../mocks/MockERC721.sol";

contract BBitsTestUtils is Test {
    BBitsBadges public badges;
    BBitsCheckIn public checkIn;
    BBitsSocial public social;
    BBitsRaffle public raffle;

    BBitsBadge7Day public badge7DayMinter;
    BBitsBadgeFirstClick public badgeFirstClickMinter;
    BBitsBadgeBearPunk public badgeBearPunkMinter;

    IERC721 public basedBits; /// @dev stand-in for BasedBits, consider forking Base?
    IERC721 public bearPunks;

    address public owner;
    address public user0;
    address public user1;
    address public user2;

    function setUp() public virtual {
        // Users
        owner = address(this);
        user0 = address(100);
        user1 = address(200);
        user2 = address(300);

        // Mocks
        basedBits = new MockERC721();
        bearPunks = new MockERC721();

        // Core
        badges = new BBitsBadges(owner);
        checkIn = new BBitsCheckIn(address(basedBits), owner);
        social = new BBitsSocial(address(checkIn),8, 140, owner);
        raffle = new BBitsRaffle(owner, basedBits, checkIn);

        // Minters
        badge7DayMinter = new BBitsBadge7Day(checkIn, badges, 1, owner);

        address[] memory minters = new address[](1);
        minters[0] = user0;
        badgeFirstClickMinter = new BBitsBadgeFirstClick(minters, badges, 2, owner);

        badgeBearPunkMinter = new BBitsBadgeBearPunk(bearPunks, checkIn, badges, 3, owner);

        badges.grantRole(badges.MINTER_ROLE(), address(badge7DayMinter));
        badges.grantRole(badges.MINTER_ROLE(), address(badgeFirstClickMinter));
        badges.grantRole(badges.MINTER_ROLE(), address(badgeBearPunkMinter));

        // Ancilalry set up
        (bool s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), user0));
        assert(s);
        (s,) = address(basedBits).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), user1));
        assert(s);
        
        (s,) = address(bearPunks).call(abi.encodeWithSelector(bytes4(keccak256("mint(address)")), user0));
        assert(s);
    }

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    /// @dev assumed to already be an owner of a BBits, will revert if not
    function setCheckInStreak(address user, uint16 streak) public {
        vm.startPrank(user);

        for (uint256 i; i < streak; i++) {
            checkIn.checkIn();
            vm.warp(block.timestamp + 1.01 days);
        }

        (, uint16 userStreak, uint16 userCount) = checkIn.checkIns(user);

        assertEq(userStreak, streak);
        assertEq(userCount, streak);

        vm.stopPrank();
    }

    function setCheckInBan(address user) public {
        vm.prank(owner);
        checkIn.ban(user);
        assertEq(checkIn.banned(user), true);
    }
}