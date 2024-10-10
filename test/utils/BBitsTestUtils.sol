// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Utils
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC721Receiver} from "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import {Reverter} from "@test/utils/Reverter.sol";

// Core
import {BBitsBadges} from "@src/BBitsBadges.sol";
import {BBitsCheckIn, IBBitsCheckIn} from "@src/BBitsCheckIn.sol";
import {BBitsSocial} from "@src/BBitsSocial.sol";
import {BBitsRaffle, IBBitsRaffle} from "@src/BBitsRaffle.sol";
import {BBITS} from "@src/BBITS.sol";
import {BBitsBurner, IBBitsBurner} from "@src/BBitsBurner.sol";
import {Emobits, Burner} from "@src/Emobits.sol";
import {IBBitsEmoji} from "@src/interfaces/IBBitsEmoji.sol";
import {BBMintRaffleNFT} from "@src/BBMintRaffleNFT.sol";
import {IBBMintRaffleNFT} from "@src/interfaces/IBBMintRaffleNFT.sol";
import {BBitsSocialRewards} from "@src/BBitsSocialRewards.sol";

// Minters
import {BBitsBadge7Day} from "@src/minters/BBitsBadge7Day.sol";
import {BBitsBadgeFirstClick} from "@src/minters/BBitsBadgeFirstClick.sol";
import {BBitsBadgeBearPunk} from "@src/minters/BBitsBadgeBearPunk.sol";

// Mocks
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {MockERC721} from "@test/mocks/MockERC721.sol";

contract BBitsTestUtils is Test, IERC721Receiver, IERC1155Receiver {
    BBitsBadges public badges;
    BBitsCheckIn public checkIn;
    BBitsSocial public social;
    BBitsRaffle public raffle;
    BBITS public bbits;
    BBitsBurner public burner;
    Emobits public emoji;
    BBMintRaffleNFT public mintRaffle;
    BBitsSocialRewards public socialRewards;

    BBitsBadge7Day public badge7DayMinter;
    BBitsBadgeFirstClick public badgeFirstClickMinter;
    BBitsBadgeBearPunk public badgeBearPunkMinter;

    IERC721 public basedBits;
    IERC721 public bearPunks;
    IERC20 public WETH;

    address public owner;
    address public user0;
    address public user1;
    address public user2;

    /// @dev Based Bits token Ids of Owner, useful for raffle tests
    uint256[5] public ownerTokenIds;

    modifier prank(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

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
        social = new BBitsSocial(address(checkIn), 8, 140, owner);
        raffle = new BBitsRaffle(owner, basedBits, checkIn);
        bbits = new BBITS(basedBits, 1024);
        emoji = new Emobits(owner, address(burner), checkIn);
        mintRaffle = new BBMintRaffleNFT(owner, user0, address(burner), 100, checkIn);
        socialRewards = new BBitsSocialRewards(owner, bbits);

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

    function forkBase() public {
        uint256 baseFork = vm.createFork("https://1rpc.io/base");
        vm.selectFork(baseFork);

        vm.warp(block.timestamp + 1000 days);

        owner = 0x1d671d1B191323A38490972D58354971E5c1cd2A;
        /// @dev Use this to access owner token Ids to allow for easy test updating
        ownerTokenIds = [6311, 5222, 5219, 4770, 3121];
    }

    /// ON RECEIVED ///

    fallback() external payable {}
    receive() external payable {}

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4) public view virtual override returns (bool) {
        return true;
    }

    /// CHECKIN ///

    /// @dev Assumed to already be an owner of a BBits, will revert if not
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

    /// RAFFLE ///

    /// @dev Assumed to be the owner when this is called
    ///      Also assumed to be in Pending Raffle status after setup
    function setRaffleStatus(IBBitsRaffle.RaffleStatus _status) public {
        if (_status == IBBitsRaffle.RaffleStatus.InRaffle) {
            /// Deposit three tokenIds
            uint256[] memory tokenIds = new uint256[](3);
            tokenIds[0] = ownerTokenIds[0];
            tokenIds[1] = ownerTokenIds[1];
            tokenIds[2] = ownerTokenIds[2];
            raffle.depositBasedBits(tokenIds);

            /// Start next raffle
            raffle.startNextRaffle();
        } else {
            /// @dev For Pending Raffle status get to just after settled
            /// Deposit three tokenIds
            uint256[] memory tokenIds = new uint256[](3);
            tokenIds[0] = ownerTokenIds[0];
            tokenIds[1] = ownerTokenIds[1];
            tokenIds[2] = ownerTokenIds[2];
            raffle.depositBasedBits(tokenIds);

            /// Start next raffle
            raffle.startNextRaffle();

            /// Settle raffle
            vm.warp(block.timestamp + 1.01 days);
            vm.roll(block.number + 2);
            raffle.settleRaffle();
        }
    }

    /// @dev Assumed to be the owner when this is called
    function setRaffleInMotionWithOnePaidEntry() internal {
        /// Deposit three tokenIds
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = ownerTokenIds[0];
        tokenIds[1] = ownerTokenIds[1];
        tokenIds[2] = ownerTokenIds[2];
        raffle.depositBasedBits(tokenIds);

        /// Start next raffle
        raffle.startNextRaffle();

        /// Owner makes an entry
        uint256 antiBotFee = raffle.antiBotFee();
        raffle.newPaidEntry{value: antiBotFee}();
    }

    /// EMOJI ///

    function addArt() internal virtual prank(owner) {
        /// Load some art
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](1);
        /// Background
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="112" y="112" width="800" height="800" fill="#E25858"/>',
            name: "AAA"
        });
        emoji.addArt(0, placeholder);
        /// Face
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="165" y="165" width="700" height="700" fill="#FFFF00"/>',
            name: "CCC"
        });
        emoji.addArt(1, placeholder);
        /// Hair
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="237" y="237" width="550" height="550" fill="#EF1F6A"/>',
            name: "DDD"
        });
        emoji.addArt(2, placeholder);
        /// Eyes
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="362" y="362" width="300" height="300" fill="#206300"/>',
            name: "FFF"
        });
        emoji.addArt(3, placeholder);
        /// Mouth
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect x="462" y="462" width="100" height="100" fill="#ADFF00"/>',
            name: "HHH"
        });
        emoji.addArt(4, placeholder);
    }
}
