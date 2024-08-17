// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Emobits} from "../../src/Emobits.sol";
import {IBBitsEmoji} from "../../src/interfaces/IBBitsEmoji.sol";

contract EmobitsArtInstall {
    Emobits public emoji;

    function _addArt() internal {
        _addBackgrounds();
        _addFaces();
        _addMouths();
        _addEyes();
        _addHairs();
    }

    function _addBackgrounds() internal {
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](1);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<rect width="21" height="21" fill="#0052FF"/>',
            name: 'AAA'
        });
        emoji.addArt(0, placeholder);
    }

    function _addFaces() internal {
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](1);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 9H6V12H5V9Z" fill="white"/><path d="M15 9H16V12H15V9Z" fill="white"/><path d="M14 12H15V14H14V12Z" fill="white"/><path d="M6 12H7V14H6V12Z" fill="white"/><path d="M7 14H8V15H7V14Z" fill="white"/><path d="M13 14H14V15H13V14Z" fill="white"/><path d="M12 15H13V16H12V15Z" fill="white"/><path d="M8 15H9V16H8V15Z" fill="white"/><path d="M9 16H12V17H9V16Z" fill="white"/><path d="M6 7H7V9H6V7Z" fill="white"/><path d="M14 7H15V9H14V7Z" fill="white"/><path d="M7 6H14V7H7V6Z" fill="white"/>',
            name: 'AAA'
        });
        emoji.addArt(1, placeholder);
    }

    function _addMouths() internal {
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](1);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<path d="M9 14V13H12V14H9Z" fill="#FF8DCF"/>',
            name: 'AAA'
        });
        emoji.addArt(2, placeholder);
    }

    function _addEyes() internal {
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](20);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 10V12H9V11H10V10H8Z" fill="yellow"/><path d="M12 12H11V10H13V11H12V12Z" fill="yellow"/>',
            name: 'Kangaroo'
        });
        placeholder[1] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 11V10H10V12H9V11H8Z" fill="yellow"/><path d="M11 11V10H13V12H12V11H11Z" fill="yellow"/>',
            name: 'Koala'
        });
        placeholder[2] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12V10H9V11H10V12H8Z" fill="yellow"/><path d="M11 12V10H12V11H13V12H11Z" fill="yellow"/>',
            name: 'Wombat'
        });
        placeholder[3] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12V11H9V10H10V12H8Z" fill="yellow"/><path d="M11 12V11H12V10H13V12H11Z" fill="yellow"/>',
            name: 'Platypus'
        });
        placeholder[4] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12V11H9V10H10V12H8Z" fill="yellow"/><path d="M11 12V10H12V11H13V12H11Z" fill="yellow"/>',
            name: 'Echidna'
        });
        placeholder[5] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12V10H9V11H10V12H8Z" fill="yellow"/><path d="M11 12V11H12V10H13V12H11Z" fill="yellow"/>',
            name: 'Dingo'
        });
        placeholder[6] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12H9V11H10V10H8V12Z" fill="yellow"/><path d="M12 11H11V10H13V12H12V11Z" fill="yellow"/>',
            name: 'Wallaby'
        });
        placeholder[7] = IBBitsEmoji.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M6 12V9H15V12H6ZM9 10H7V11H9V10ZM14 10H12V11H14V10Z" fill="yellow"/>',
            name: 'Emu'
        });
        placeholder[8] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 11H6V10H7V9H10V10H11V9H14V10H15V11H14V12H11V11H10V12H7V11Z" fill="yellow"/><path d="M8 10H9V11H8V10Z" fill="white"/><path d="M12 10H13V11H12V10Z" fill="white"/>',
            name: 'Quokka'
        });
        placeholder[9] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 11H6V10H7V9H10V10H11V9H14V10H15V11H14V12H11V11H10V12H7V11Z" fill="yellow"/>',
            name: 'Numbat'
        });
        placeholder[10] = IBBitsEmoji.NamedBytes({
            core: '<path d="M9 12H6V9H9V10H12V9H15V12H12V11H11V12H10V11H9V12Z" fill="yellow"/><path d="M9 8H12V9H9V8Z" fill="yellow"/><path d="M7 10H8V11H7V10Z" fill="white"/><path d="M13 10H14V11H13V10Z" fill="white"/>',
            name: 'Kookaburra'
        });
        placeholder[11] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 9H10V12H7V9Z" fill="white"/><path d="M11 9H14V12H11V9Z" fill="white"/><path d="M8 10H9V11H8V10Z" fill="yellow"/><path d="M12 10H13V11H12V10Z" fill="yellow"/>',
            name: 'Bilby'
        });
        placeholder[12] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 12H10V11H11V12H16V9H5V12Z" fill="yellow"/><path d="M8 10H9V11H8V10Z" fill="white"/><path d="M12 10H13V11H12V10Z" fill="white"/>',
            name: 'Sea Turtle'
        });
        placeholder[13] = IBBitsEmoji.NamedBytes({
            core: '<path d="M15 9H6V12H9V11H10V10H11V11H12V12H15V9Z" fill="yellow"/><path d="M5 9H6V12H5V9Z" fill="black"/><path d="M15 9H16V12H15V9Z" fill="black"/><path d="M6 8H15V9H6V8Z" fill="black"/><path d="M6 12H9V13H6V12Z" fill="black"/><path d="M12 12H15V13H12V12Z" fill="black"/><path d="M11 11H12V12H11V11Z" fill="black"/><path d="M10 10H11V11H10V10Z" fill="black"/><path d="M9 11H10V12H9V11Z" fill="black"/>',
            name: 'Lorikeet'
        });
        placeholder[14] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 12V10H8V11H9V10H10V12H7Z" fill="white"/><path d="M11 12V10H12V11H13V10H14V12H11Z" fill="white"/><path d="M8 10H9V11H8V10Z" fill="yellow"/><path d="M12 10H13V11H12V10Z" fill="yellow"/>',
            name: 'Whale'
        });
        placeholder[15] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 12H7V10H10V12H9V11H8V12Z" fill="yellow"/><path d="M11 10V12H12V11H13V12H14V10H11Z" fill="yellow"/><path d="M8 11H9V12H8V11Z" fill="white"/><path d="M12 11H13V12H12V11Z" fill="white"/>',
            name: 'Spider'
        });
        placeholder[16] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 10H9V11H8V10Z" fill="white"/><path d="M11 10H12V11H11V10Z" fill="white"/><path d="M9 10H10V11H9V10Z" fill="yellow"/><path d="M12 10H13V11H12V10Z" fill="yellow"/>',
            name: 'Seal'
        });
        placeholder[17] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 10H9V11H8V10Z" fill="white"/><path d="M12 10H13V11H12V10Z" fill="white"/><path d="M12 9H13V10H12V9Z" fill="yellow"/><path d="M11 10H12V11H11V10Z" fill="yellow"/><path d="M12 11H13V12H12V11Z" fill="yellow"/><path d="M13 10H14V11H13V10Z" fill="yellow"/><path d="M8 9H9V10H8V9Z" fill="yellow"/><path d="M7 10H8V11H7V10Z" fill="yellow"/><path d="M8 11H9V12H8V11Z" fill="yellow"/><path d="M9 10H10V11H9V10Z" fill="yellow"/>',
            name: 'Frog'
        });
        placeholder[18] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 11V10H10V11H8Z" fill="yellow"/><path d="M11 11V10H13V11H11Z" fill="yellow"/>',
            name: 'Goanna'
        });
        placeholder[19] = IBBitsEmoji.NamedBytes({
            core: '<path d="M9 12H8V11H7V10H10V11H9V12Z" fill="yellow"/><path d="M11 11V10H14V11H13V12H12V11H11Z" fill="yellow"/>',
            name: 'Possum'
        });
        emoji.addArt(3, placeholder);
    }

    function _addHairs() internal {
        IBBitsEmoji.NamedBytes[] memory placeholder = new IBBitsEmoji.NamedBytes[](35);
        placeholder[0] = IBBitsEmoji.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M4 19H7V16H6V12H4V11H3V8H4V10H6V8H9V7H10V4H9V2H6V5H5V3H2V6H5V7H2V15H5V16H4V19ZM6 5V6H7V5H6ZM7 3H8V4H7V3ZM3 4H4V5H3V4ZM3 13H4V14H3V13ZM6 17H5V18H6V17Z" fill="white"/><path fill-rule="evenodd" clip-rule="evenodd" d="M11 7V4H12V2H15V5H14V6H15V5H16V3H19V6H16V7H19V15H16V16H17V19H14V16H15V12H17V11H18V8H17V10H15V8H12V7H11ZM14 3H13V4H14V3ZM17 4H18V5H17V4ZM18 13H17V14H18V13ZM15 17H16V18H15V17Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[1] = IBBitsEmoji.NamedBytes({
            core: '<path d="M6 11H4V10H5V9H3V8H2V7H4V8H6V7H5V6H6V4H7V6H8V3H9V6H10V2H11V6H12V3H13V6H14V4H15V6H16V7H15V8H17V7H19V8H18V9H16V10H17V11H15V9H14V8H13V7H11V8H10V7H8V8H7V9H6V11Z" fill="white"/><path d="M7 16V15H8V18H7V17H5V16H7Z" fill="white"/><path d="M13 18V15H14V16H16V17H14V18H13Z" fill="white"/><path d="M11 18V17H10V18H9V19H12V18H11Z" fill="white"/><path d="M4 14H7V15H4V14Z" fill="white"/><path d="M14 14H17V15H14V14Z" fill="white"/><path d="M3 15H4V16H3V15Z" fill="white"/><path d="M3 13H4V14H3V13Z" fill="white"/><path d="M3 11H4V12H3V11Z" fill="white"/><path d="M2 9H3V10H2V9Z" fill="white"/><path d="M4 4H5V5H4V4Z" fill="white"/><path d="M7 2H8V3H7V2Z" fill="white"/><path d="M13 2H14V3H13V2Z" fill="white"/><path d="M17 5H18V6H17V5Z" fill="white"/><path d="M18 9H19V10H18V9Z" fill="white"/><path d="M17 11H18V12H17V11Z" fill="white"/><path d="M17 13H18V14H17V13Z" fill="white"/><path d="M17 15H18V16H17V15Z" fill="white"/><path d="M14 18H15V19H14V18Z" fill="white"/><path d="M6 18H7V19H6V18Z" fill="white"/><path d="M16 4H17V6H16V4Z" fill="white"/><path d="M3 5H5V6H3V5Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[2] = IBBitsEmoji.NamedBytes({
            core: '<path d="M3 12H5V9H6V7H7V8H8V7H9V8H10V10H11V8H12V7H13V8H14V7H15V9H16V12H18V14H19V10H18V9H19V7H17V6H15V5H19V3H18V4H17V3H15V2H12V3H11V5H10V3H9V2H6V3H4V4H3V3H2V5H6V6H4V7H2V9H3V10H2V14H3V12Z" fill="white"/><path d="M7 13H6V14H5V15H3V16H2V17H3V19H4V18H5V17H7V16H8V15H7V13Z" fill="white"/><path d="M14 15V13H15V14H16V15H18V16H19V17H18V19H17V18H16V17H14V16H13V15H14Z" fill="white"/><path d="M8 18V17H13V18H11V19H10V18H8Z" fill="white"/><path d="M5 12H8V13H5V12Z" fill="white"/><path d="M13 12H16V13H13V12Z" fill="white"/><path d="M10 15H11V16H10V15Z" fill="white"/><path d="M8 16H9V17H8V16Z" fill="white"/><path d="M12 16H13V17H12V16Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[3] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 15H8V16H7V15Z" fill="white"/><path d="M13 15H14V16H13V15Z" fill="white"/><path d="M6 7V9H5V5H6V3H7V2H8V5H9V6H7V7H6Z" fill="white"/><path d="M12 6V5H13V2H14V3H15V5H16V9H15V7H14V6H12Z" fill="white"/><path d="M12 7H9V8H10V9H11V8H12V7Z" fill="white"/><path d="M7 9V8H8V9H7Z" fill="white"/><path d="M14 8H13V9H14V8Z" fill="white"/><path d="M6 13H8V14H7V15H6V13Z" fill="white"/><path d="M13 14V13H15V15H14V14H13Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[4] = IBBitsEmoji.NamedBytes({
            core: '<path d="M2 3H5V4H2V3Z" fill="white"/><path d="M7 3H9V4H7V3Z" fill="white"/><path d="M10 3H11V4H10V3Z" fill="white"/><path d="M11 4H12V5H11V4Z" fill="white"/><path d="M4 4H5V5H4V4Z" fill="white"/><path d="M4 7H5V8H4V7Z" fill="white"/><path d="M8 8H9V9H8V8Z" fill="white"/><path d="M13 8H14V9H13V8Z" fill="white"/><path d="M12 9H13V10H12V9Z" fill="white"/><path d="M13 10H14V11H13V10Z" fill="white"/><path d="M12 12H13V13H12V12Z" fill="white"/><path d="M10 11H12V12H10V11Z" fill="white"/><path d="M10 9H11V10H10V9Z" fill="white"/><path d="M3 11H4V12H3V11Z" fill="white"/><path d="M7 12H8V13H7V12Z" fill="white"/><path d="M8 13H9V14H8V13Z" fill="white"/><path d="M9 15H10V16H9V15Z" fill="white"/><path d="M11 14H12V15H11V14Z" fill="white"/><path d="M12 16H13V17H12V16Z" fill="white"/><path d="M17 16H19V17H17V16Z" fill="white"/><path d="M17 18H18V19H17V18Z" fill="white"/><path d="M14 17H16V18H14V17Z" fill="white"/><path d="M9 18H11V19H9V18Z" fill="white"/><path d="M3 17H5V18H3V17Z" fill="white"/><path d="M5 15H6V16H5V15Z" fill="white"/><path d="M5 18H6V19H5V18Z" fill="white"/><path d="M13 18H14V19H13V18Z" fill="white"/><path d="M14 12H15V13H14V12Z" fill="white"/><path d="M15 13H18V14H15V13Z" fill="white"/><path d="M14 15H16V16H14V15Z" fill="white"/><path d="M4 13H6V14H4V13Z" fill="white"/><path d="M2 15H4V16H2V15Z" fill="white"/><path d="M6 16H8V17H6V16Z" fill="white"/><path d="M3 9H5V10H3V9Z" fill="white"/><path d="M7 10H9V11H7V10Z" fill="white"/><path d="M16 8H17V9H16V8Z" fill="white"/><path d="M18 9H19V10H18V9Z" fill="white"/><path d="M16 10H18V11H16V10Z" fill="white"/><path d="M3 6H4V7H3V6Z" fill="white"/><path d="M12 5H13V6H12V5Z" fill="white"/><path d="M5 5H6V6H5V5Z" fill="white"/><path d="M15 5H16V6H15V5Z" fill="white"/><path d="M7 5H9V6H7V5Z" fill="white"/><path d="M8 7H11V8H8V7Z" fill="white"/><path d="M13 4H14V5H13V4Z" fill="white"/><path d="M14 3H16V4H14V3Z" fill="white"/><path d="M16 2H17V3H16V2Z" fill="white"/><path d="M17 4H19V5H17V4Z" fill="white"/><path d="M14 6H17V7H14V6Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[5] = IBBitsEmoji.NamedBytes({
            core: '<path d="M4 10H7V9H6V7H7V6H5V5H4V3H5V2H3V3H2V8H3V9H4V10Z" fill="white"/><path d="M16 6H14V7H15V9H14V10H17V9H18V8H19V3H18V2H16V3H17V5H16V6Z" fill="white"/><path d="M9 4H12V5H9V4Z" fill="white"/><path d="M7 5H14V6H7V5Z" fill="white"/><path d="M7 7H14V8H7V7Z" fill="white"/><path d="M8 8H13V9H8V8Z" fill="white"/><path d="M10 9H11V10H10V9Z" fill="white"/><path d="M9 15H12V16H9V15Z" fill="white"/><path d="M8 14H9V15H8V14Z" fill="white"/><path d="M12 14H13V15H12V14Z" fill="white"/><path d="M13 13H14V14H13V13Z" fill="white"/><path d="M7 13H8V14H7V13Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[6] = IBBitsEmoji.NamedBytes({
            core: '<path d="M4 11H5V10H6V7H7V6H10V5H9V4H8V3H7V5H6V6H5V9H4V11Z" fill="white"/><path d="M11 5V6H14V7H15V10H16V11H17V9H16V6H15V5H14V3H13V4H12V5H11Z" fill="white"/><path d="M9 8V7H12V8H11V9H10V8H9Z" fill="white"/><path d="M7 7H8V8H7V7Z" fill="white"/><path d="M13 7H14V8H13V7Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[7] = IBBitsEmoji.NamedBytes({
            core: '<path d="M3 19H8V18H9V16H8V15H7V14H6V12H7V10H8V9H9V8H10V7H11V8H12V9H13V10H14V12H15V14H14V15H13V16H12V18H13V19H18V18H17V9H16V7H15V6H14V5H11V6H10V5H7V6H6V7H5V9H4V18H3V19Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[8] = IBBitsEmoji.NamedBytes({
            core: '<path d="M6 6V7H7V9H8V8H10V7H11V8H13V9H14V7H15V6H14V5H12V4H13V3H12V2H9V3H8V4H9V5H7V6H6Z" fill="white"/><path d="M5 7H6V9H5V7Z" fill="white"/><path d="M15 7H16V9H15V7Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[9] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 7V6H14V7H13V8H12V7H11V8H10V7H9V8H8V7H7Z" fill="white"/><path d="M6 7H7V8H6V7Z" fill="white"/><path d="M9 8H10V9H9V8Z" fill="white"/><path d="M11 8H12V9H11V8Z" fill="white"/><path d="M14 7H15V8H14V7Z" fill="white"/><path d="M10 15H11V16H10V15Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[10] = IBBitsEmoji.NamedBytes({
            core: '<path d="M4 11H5V9H6V8H8V7H10V8H11V7H13V8H14V7H15V9H16V11H17V9H18V8H16V7H17V5H16V6H15V4H14V5H13V3H12V5H11V4H10V5H9V3H8V5H7V4H6V6H5V5H4V7H5V8H3V9H4V11Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[11] = IBBitsEmoji.NamedBytes({
            core: '<path d="M15 7H16V6H15V5H14V6H13V5H12V6H11V5H10V6H9V5H8V6H7V5H6V6H5V7H6V8H8V7H10V8H11V7H13V8H15V7Z" fill="white"/><path d="M4 8H6V9H4V8Z" fill="white"/><path d="M4 10H5V11H4V10Z" fill="white"/><path d="M15 8H17V9H15V8Z" fill="white"/><path d="M16 10H17V11H16V10Z" fill="white"/><path d="M14 14H16V15H14V14Z" fill="white"/><path d="M5 14H7V15H5V14Z" fill="white"/><path d="M7 15H8V17H7V15Z" fill="white"/><path d="M10 17H11V18H10V17Z" fill="white"/><path d="M13 15H14V17H13V15Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[12] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 17H6V18H3V17H2V14H3V9H4V6H5V5H7V4H14V5H16V6H17V9H18V14H19V17H18V18H15V17H14V14H15V12H16V9H14V8H12V7H11V6H10V7H9V6H7V7H6V8H8V9H5V12H6V14H7V17Z" fill="white"/><path d="M8 8V7H9V8H8Z" fill="white"/><path d="M11 8H12V9H11V8Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[13] = IBBitsEmoji.NamedBytes({
            core: '<path d="M6 8H10V7H11V8H15V7H14V6H7V7H6V8Z" fill="white"/><path d="M9 17V16H8V18H9V19H12V18H13V16H12V17H9Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[14] = IBBitsEmoji.NamedBytes({
            core: '<path d="M4 11H5V9H6V8H9V7H12V8H15V9H16V11H17V7H16V5H15V4H14V3H11V4H10V3H7V4H6V5H5V7H4V11Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[15] = IBBitsEmoji.NamedBytes({
            core: '<path d="M4 11H5V9H6V7H8V6H10V7H12V8H15V10H16V12H15V14H14V16H15V15H16V14H17V12H18V13H19V10H18V9H17V8H19V7H18V6H17V5H15V4H17V3H16V2H11V3H10V4H9V3H8V4H7V6H5V7H4V11Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[16] = IBBitsEmoji.NamedBytes({
            core: '<path d="M3 18H6V17H7V16H8V15H7V14H6V12H5V9H6V10H7V8H8V6H9V7H11V8H12V10H13V9H14V7H15V9H16V12H15V14H14V15H13V16H14V17H15V18H18V17H19V16H17V15H18V14H19V13H18V11H19V8H18V9H17V6H18V3H17V4H15V3H14V4H13V2H11V3H10V2H9V3H8V4H7V5H6V4H4V5H3V7H2V8H3V9H2V11H3V10H4V12H3V13H2V14H3V15H4V16H2V17H3V18Z" fill="white"/><path d="M8 8H9V9H8V8Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[17] = IBBitsEmoji.NamedBytes({
            core: '<path d="M9 18H7V19H4V18H5V17H6V16H3V15H2V14H4V13H3V12H2V9H3V10H4V8H3V4H4V3H5V6H6V4H7V3H9V2H10V5H11V3H12V2H15V3H17V4H18V5H15V6H17V7H18V8H19V9H18V10H19V11H18V13H19V15H18V14H17V15H16V16H17V17H16V18H15V19H14V18H13V17H12V18H10V17H11H12V16H13V15H14V14H15V12H16V9H15V7H14V8H13V7H12V8H9V7H8V8H7V7H6V9H5V12H6V14H7V15H8V16H9V18Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[18] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 18H9V16H8V15H7V14H6V10H7V9H8V8H10V7H11V9H12V8H13V9H14V10H15V14H14V15H13V16H12V18H13V19H18V18H17V9H16V7H15V6H14V5H11V6H10V5H7V6H6V7H5V9H4V18H3V19H8V18Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[19] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 16V17H3V16H2V15H4V14H2V13H3V12H4V10H3V7H4V5H5V4H6V3H9V4H12V3H15V4H16V5H17V7H18V10H17V12H18V13H19V14H17V15H19V16H18V17H14V16H13V15H14V14H15V9H14V8H13V7H11V6H10V7H11V8H10V9H9V7H8V8H7V9H6V14H7V15H8V16H7Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[20] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 14H6V12H5V9H6V8H7V7H8V8H9V5H8V4H6V5H4V6H3V7H2V10H3V12H4V13H5V14Z" fill="white"/><path d="M13 7V9H12V8H11V7H12V5H13V4H15V5H17V6H18V7H19V10H18V12H17V13H16V14H15V12H16V9H15V8H14V7H13Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[21] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 9H6V7H7V6H10V8H11V9H12V7H13V8H14V9H16V6H15V5H14V4H7V5H6V6H5V9Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[22] = IBBitsEmoji.NamedBytes({
            core: '<path d="M6 15H4V14H3V12H4V11H3V9H4V8H6V6H7V5H8V4H9V3H11V4H12V5H13V4H14V3H16V4H17V6H16V7H15V8H17V9H18V11H17V12H18V14H17V15H15V12H16V9H15V8H14H13V7H11V9H10V8H9V7H8V8H7H6V9H5V12H6V15Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[23] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 12H6V7H8V8H13V7H15V12H16V11H17V10H18V7H17V6H15V5H14V4H7V5H6V6H4V7H3V10H4V11H5V12Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[24] = IBBitsEmoji.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M7 16H8V15H7V13H6V12H5V9H8V8H9V6H10V8H11V9H12V8H13V9H14V8H13V6H14V7H15V9H16V12H15V13H14V15H13V16H14V17H15V15H16V16H18V15H17V14H18V13H17V9H16V7H15V6H14V5H7V6H6V7H5V9H4V13H3V14H4V15H3V16H5V15H6V17H7V16ZM12 8V7H11V8H12ZM7 8H8V7H7V8Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[25] = IBBitsEmoji.NamedBytes({
            core: '<path d="M3 17H6V16H7V14H6V12H5V10H7V8H9V7H10V8H13V9H14V10H16V12H15V14H14V16H15V17H18V16H17V8H16V6H15V5H13V4H8V5H6V6H5V8H4V16H3V17Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[26] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 7H9V8H8V7Z" fill="white"/><path d="M9 8H10V9H9V8Z" fill="white"/><path d="M7 13H8V14H7V13Z" fill="white"/><path d="M13 13H14V14H13V13Z" fill="white"/><path d="M10 15H11V16H10V15Z" fill="white"/><path d="M10 17H11V18H10V17Z" fill="white"/><path d="M4 11H5V9H6V7H7V6H14V7H15V9H16V11H17V9H18V5H17V4H16V3H14V2H7V3H5V4H4V6H3V9H4V11Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[27] = IBBitsEmoji.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M2 14H3V13H4V12H3V11H4V10H3V9H4V8H3V7H4V6H5V10H6V7H7V6H10V8H11V6H14V7H15V10H16V6H17V7H18V8H17V9H18V10H17V11H18V12H17V13H18V14H19V13H18V12H19V11H18V10H19V9H18V8H19V5H18V4H17V3H15V2H12V3H11V4H10V3H9V2H6V3H4V4H3V5H2V8H3V9H2V10H3V11H2V12H3V13H2V14ZM15 5H16V6H15V5ZM15 5H13V4H15V5ZM6 5H5V6H6V5ZM6 5V4H8V5H6Z" fill="white"/><path d="M16 13H15V12H16V13Z" fill="white"/><path d="M5 16V17H7V14H5V15H6V16H5Z" fill="white"/><path d="M10 15V16H8V17H9V18H10V19H11V18H12V17H13V16H11V15H10Z" fill="white"/><path d="M15 15H16V14H14V17H16V16H15V15Z" fill="white"/><path d="M5 13H6V12H5V13Z" fill="white"/><path d="M8 7H9V9H8V7Z" fill="white"/><path d="M12 9H13V7H12V9Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[28] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 16H8V15H7V14H6V12H5V16H4V17H7V16Z" fill="white"/><path d="M14 17H17V16H16V12H15V14H14V15H13V16H14V17Z" fill="white"/><path d="M6 9H9V8H10V5H6V6H5V10H6V9Z" fill="white"/><path d="M12 8H11V5H15V6H16V10H15V9H12V8Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[29] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 16H8V15H7V14H6V12H5V16H4V17H7V16Z" fill="white"/><path d="M14 16H13V15H14V14H15V12H16V16H17V17H14V16Z" fill="white"/><path d="M4 13H3V12H2V6H3V5H6V4H7V3H10V4H11V3H14V4H13V5H14V4H15V5H18V6H19V12H18V13H17V7H16V9H15V10H14V9H12V8H10V7H9V6H8V8H9V9H7V10H6V9H5V7H4V13Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[30] = IBBitsEmoji.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M7 16H8V15H7V14H6V12H5V9H7V7H8V6H9V8H14V9H16V12H15V14H14V15H13V16H14V15H16V14H17V7H16V5H15V4H9V5H8V4H6V5H5V7H4V14H5V15H7V16ZM15 5V6H13V5H15Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[31] = IBBitsEmoji.NamedBytes({
            core: '<path d="M6 17H7V16H8V13H7V10H8V9H10V8H11V9H13V10H14V13H13V16H14V17H15V16H16V14H15V12H16V8H15V6H14V5H12V6H11V5H10V6H9V5H7V6H6V8H5V12H6V14H5V16H6V17Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[32] = IBBitsEmoji.NamedBytes({
            core: '<path d="M5 17H7V9H10V8H12V7H13V9H14V17H16V9H15V7H14V6H12V5H9V6H7V7H6V9H5V17Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[33] = IBBitsEmoji.NamedBytes({
            core: '<path d="M8 9H6V7H7V6H8V5H12V6H14V7H15V9H16V12H15V11H14V10H13V9H11V8H9V7H8V9Z" fill="white"/>',
            name: 'AAA'
        });
        placeholder[34] = IBBitsEmoji.NamedBytes({
            core: '<path d="M7 7H6V8H8V7H9V8H12V7H13V8H15V7H14V6H13V5H8V6H7V7Z" fill="white"/>',
            name: 'AAA'
        });
        emoji.addArt(4, placeholder);
    }
}