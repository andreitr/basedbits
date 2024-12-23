// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Punkalot} from "@src/Punkalot.sol";
import {IPunksALot} from "@src/interfaces/IPunksALot.sol";

contract PunksALotArtInstall {
    Punkalot public punksALot;

    function _addArt() internal {
        _addBackgrounds();
        _addBodies();
        _addHeads();
        _addMouths();
        _addEyes();
    }

    function _addBackgrounds() internal {
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](2);
        placeholder[0] = IPunksALot.NamedBytes({core: '<rect width="24" height="24" fill="#DBAEB4"/>', name: "Pink"});
        placeholder[1] = IPunksALot.NamedBytes({core: '<rect width="24" height="24" fill="#B9B9B7"/>', name: "Gray"});
        punksALot.addArt(0, placeholder);
    }

    function _addBodies() internal {
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](1);
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M7 15V24H10V21H16V6H7V12H6V15H7Z" fill="#53A3FC"/><path d="M6 15H7V24H6V15Z" fill="#3B7AFF"/><path d="M5 12H6V15H5V12Z" fill="#3B7AFF"/><path d="M6 6H7V12H6V6Z" fill="#3B7AFF"/><path d="M7 5H16V6H7V5Z" fill="#3B7AFF"/><path d="M16 6H17V21H16V6Z" fill="#3B7AFF"/><path d="M9 21H16V22H9V21Z" fill="#3B7AFF"/><path d="M8 20H9V21H8V20Z" fill="#3B7AFF"/><path d="M10 22H11V24H10V22Z" fill="#3B7AFF"/><path d="M12 15H15V16H12V15Z" fill="#3B7AFF"/><path d="M7 7H8V9H7V7Z" fill="#82BCFC"/><path d="M8 6H9V7H8V6Z" fill="#82BCFC"/>',
            name: "Based Punk"
        });
        punksALot.addArt(1, placeholder);
    }

    function _addHeads() internal {
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](14);
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M5 10H6V9H12V8H13V9H14V8H15V9H18V6H17V5H16V4H7V5H6V6H5V10Z" fill="#303135"/><path d="M12 5H13V6H12V5Z" fill="#52535A"/><path d="M6 3H7V4H6V3Z" fill="#303135"/><path d="M15 5H16V6H15V5Z" fill="#52535A"/><path d="M13 6H14V8H13V6Z" fill="#52535A"/><path d="M16 6H17V8H16V6Z" fill="#52535A"/>',
            name: "Bowl Cut"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M18 10H2V9H6V6H7V5H8V4H15V5H16V6H17V7H18V10ZM15 9H12V7H13V6H14V7H15V9Z" fill="#303135"/>',
            name: "Cap Back"
        });
        placeholder[2] = IPunksALot.NamedBytes({
            core: '<path d="M6 9H22V8H17V5H16V4H15V3H7V4H6V9Z" fill="#303135"/><path d="M13 5H15V7H13V5Z" fill="#52535A"/>',
            name: "Cap"
        });
        placeholder[3] = IPunksALot.NamedBytes({
            core: '<path d="M5 12H6V11H7V10H8V8H9V7H12V8H14V7H17V11H18V10H19V6H18V5H17V4H16V3H9V2H8V3H7V4H6V5H5V7H4V11H5V12Z" fill="#303135"/><path d="M6 2H7V3H6V2Z" fill="#303135"/>',
            name: "Hair"
        });
        placeholder[4] = IPunksALot.NamedBytes({
            core: '<path d="M5 8H7V9H5V8Z" fill="#303135"/><path d="M5 5H6V6H5V5Z" fill="#303135"/><path d="M8 2H9V4H8V2Z" fill="#303135"/><path d="M9 4H10V6H9V4Z" fill="#303135"/><path d="M11 4H12V5H11V4Z" fill="#303135"/><path d="M12 3H13V4H12V3Z" fill="#303135"/><path d="M14 3H15V5H14V3Z" fill="#303135"/><path d="M15 2H16V3H15V2Z" fill="#303135"/><path d="M16 3H17V4H16V3Z" fill="#303135"/><path d="M17 6H18V7H17V6Z" fill="#303135"/>',
            name: "Bad Hair"
        });
        placeholder[5] = IPunksALot.NamedBytes({
            core: '<path d="M5 21H6V15H5V12H7V10H8V9H9V8H15V9H17V11H18V10H19V6H18V4H17V3H16V2H14V3H13V2H6V3H5V4H4V7H3V8H2V14H3V16H4V20H5V21Z" fill="#303135"/><path d="M7 4H8V5H7V4Z" fill="#52535A"/><path d="M6 5H7V6H6V5Z" fill="#52535A"/><path d="M15 4H16V5H15V4Z" fill="#52535A"/><path d="M16 5H17V7H16V5Z" fill="#52535A"/>',
            name: "Big Hair"
        });
        placeholder[6] = IPunksALot.NamedBytes({
            core: '<path d="M4 9H19V8H17V2H6V8H4V9Z" fill="#303135"/><path d="M15 3H16V5H15V3Z" fill="#52535A"/><path d="M6 7H17V8H6V7Z" fill="#52535A"/>',
            name: "Monopoly"
        });
        placeholder[7] = IPunksALot.NamedBytes({
            core: '<path d="M7 15H8V17H7V15Z" fill="#CEDFFB"/><path d="M5 3H6V4H5V3Z" fill="#CEDFFB"/><path fill-rule="evenodd" clip-rule="evenodd" d="M6 15V24H2V23H3V22H4V10H5V6H6V4H8V3H15V4H16V5H17V7H18V10H17V9H8V10H7V15H6ZM6 15H5V12H6V15Z" fill="#CEDFFB"/>',
            name: "Long Gray Hair"
        });
        placeholder[8] = IPunksALot.NamedBytes({
            core: '<path fill-rule="evenodd" clip-rule="evenodd" d="M5 9H17V6H16V5H15V4H8V5H7V6H6V8H5V9ZM15 6H14V7H15V8H16V7H15V6Z" fill="#3B7AFF"/><path d="M3 7H5V8H3V7Z" fill="#3B7AFF"/><path d="M4 9H5V10H4V9Z" fill="#53A3FC"/>',
            name: "Bandit"
        });
        placeholder[9] = IPunksALot.NamedBytes({
            core: '<path d="M5 5H6V6H5V5Z" fill="#303135"/><path d="M7 4H8V6H7V4Z" fill="#303135"/><path d="M9 4H10V6H9V4Z" fill="#303135"/><path d="M11 4H12V6H11V4Z" fill="#303135"/><path d="M13 4H14V6H13V4Z" fill="#303135"/><path d="M15 4H16V6H15V4Z" fill="#303135"/><path d="M17 5H18V6H17V5Z" fill="#303135"/><path d="M14 5H15V6H14V5Z" fill="#52535A"/><path d="M12 5H13V6H12V5Z" fill="#52535A"/><path d="M10 5H11V6H10V5Z" fill="#52535A"/><path d="M8 5H9V6H8V5Z" fill="#52535A"/>',
            name: "Flat Top"
        });
        placeholder[10] = IPunksALot.NamedBytes({
            core: '<path d="M2 10H3V11H2V10Z" fill="#CEDFFB"/><path d="M4 2H5V3H4V2Z" fill="#CEDFFB"/><path d="M20 2H21V3H20V2Z" fill="#CEDFFB"/><path d="M19 8H20V9H19V8Z" fill="#CEDFFB"/><path d="M18 10H19V11H18V10Z" fill="#CEDFFB"/><path d="M5 17H6V15H7V11H8V9H10V8H15V9H17V10H18V8H19V7H20V5H19V4H20V3H18V4H17V3H16V1H15V2H14V1H13V2H12V3H11V2H9V1H8V2H6V3H5V4H4V5H3V7H2V8H3V10H4V12H3V14H4V15H5V17Z" fill="#CEDFFB"/>',
            name: "Messy Gray Hair"
        });
        placeholder[11] = IPunksALot.NamedBytes({
            core: '<path d="M18 6V12H17V10H16V11H15V9H14V10H13V8H12V9H11V8H10V7H9V8H8V6H6V5H7V4H8V3H15V4H16V5H17V6H18Z" fill="#303135"/><path d="M6 7H7V8H6V7Z" fill="#303135"/><path d="M6 9H7V10H6V9Z" fill="#303135"/><path d="M8 9H9V10H8V9Z" fill="#303135"/>',
            name: "Emo"
        });
        placeholder[12] = IPunksALot.NamedBytes({
            core: '<path d="M9 2H10V3H9V2Z" fill="#303135"/><path d="M14 2H15V3H14V2Z" fill="#303135"/><path d="M8 7H10V5H9V3H8V4H7V6H8V7Z" fill="#303135"/><path d="M14 4V5H16V3H15V4H14Z" fill="#303135"/>',
            name: "Devil"
        });
        placeholder[13] = IPunksALot.NamedBytes({
            core: '<path d="M13 5V6H12V8H14V7H15V6H16V4H17V2H16V3H15V4H14V5H13Z" fill="#CEDFFB"/><path d="M17 1H18V2H17V1Z" fill="#CEDFFB"/>',
            name: "Unicorn"
        });
        punksALot.addArt(2, placeholder);
    }

    function _addMouths() internal {
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](15);
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M11 19V18H17V17H18V21H17V19H11Z" fill="#3B7AFF"/><path d="M10 17H11V18H10V17Z" fill="#3B7AFF"/><path d="M12 17H13V18H12V17Z" fill="#CEDFFB"/><path d="M16 17H17V18H16V17Z" fill="#CEDFFB"/><path d="M16 21H17V22H16V21Z" fill="#3B7AFF"/><path d="M16 19H17V21H16V19Z" fill="#53A3FC"/>',
            name: "Troll"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path d="M10 17H11V18H10V17Z" fill="#3B7AFF"/><path d="M11 18H14V19H11V18Z" fill="#3B7AFF"/>',
            name: "Regular Smile"
        });
        placeholder[2] = IPunksALot.NamedBytes({
            core: '<path d="M9 19H10V18H16V17H9V19Z" fill="#3B7AFF"/><path d="M10 19H16V20H10V19Z" fill="#3B7AFF"/><path d="M10 18H16V19H10V18Z" fill="#CEDFFB"/>',
            name: "All Teeth"
        });
        placeholder[3] = IPunksALot.NamedBytes({
            core: '<path d="M10 18V19H9V17H16V18H10Z" fill="#3B7AFF"/><path d="M10 19H16V20H10V19Z" fill="#3B7AFF"/><path d="M10 18H11V19H10V18Z" fill="#CEDFFB"/><path d="M12 18H13V19H12V18Z" fill="#CEDFFB"/><path d="M14 18H15V19H14V18Z" fill="#CEDFFB"/><path d="M11 18H12V19H11V18Z" fill="#303135"/><path d="M13 18H14V19H13V18Z" fill="#303135"/><path d="M15 18H16V19H15V18Z" fill="#303135"/>',
            name: "No Teeth"
        });
        placeholder[4] = IPunksALot.NamedBytes({
            core: '<path d="M7 19V15H8V16H18V21H17V22H10V21H9V20H8V19H7Z" fill="#303135"/><path d="M11 18H15V19H11V18Z" fill="#3B7AFF"/>',
            name: "Short Beard"
        });
        placeholder[5] = IPunksALot.NamedBytes({
            core: '<path d="M6 20V15H7V16H17V24H9V23H8V22H7V20H6Z" fill="#303135"/><path d="M9 17H10V18H9V17Z" fill="#3B7AFF"/><path d="M10 18H14V19H10V18Z" fill="#3B7AFF"/>',
            name: "Long Beard"
        });
        placeholder[6] = IPunksALot.NamedBytes({
            core: '<path d="M9 15H10V16H9V15Z" fill="#303135"/><path d="M17 15H18V16H17V15Z" fill="#303135"/><path d="M8 16H9V17H8V16Z" fill="#303135"/><path d="M18 16H19V17H18V16Z" fill="#303135"/><path d="M9 17H11V18H9V17Z" fill="#303135"/><path d="M11 17H16V18H11V17Z" fill="#3B7AFF"/><path d="M16 17H18V18H16V17Z" fill="#303135"/><path d="M11 16H16V17H11V16Z" fill="#303135"/>',
            name: "Dali"
        });
        placeholder[7] = IPunksALot.NamedBytes({
            core: '<path d="M10 17H16V18H10V17Z" fill="#F5BFC7"/><path d="M10 18H11V19H10V18Z" fill="#303135"/><path d="M13 18H14V19H13V18Z" fill="#303135"/><path d="M11 18H13V19H11V18Z" fill="#CEDFFB"/><path d="M14 18H16V19H14V18Z" fill="#CEDFFB"/>',
            name: "Bucktooth"
        });
        placeholder[8] = IPunksALot.NamedBytes({
            core: '<path d="M9 19H11V18H16V19H18V18H17V17H16V16H15V17H12V16H11V17H10V18H9V19Z" fill="#303135"/><path d="M12 15H15V17H12V15Z" fill="#F5BFC7"/><path d="M11 18H13V19H11V18Z" fill="#CEDFFB"/><path d="M14 18H16V19H14V18Z" fill="#CEDFFB"/>',
            name: "Disguise"
        });
        placeholder[9] = IPunksALot.NamedBytes({
            core: '<path d="M9 16H10V17H9V16Z" fill="#3B7AFF"/><path d="M18 19H19V17H18V19Z" fill="#3B7AFF"/><path d="M14 19H18V20H14V19Z" fill="#3B7AFF"/><path d="M17 17H10V18H18V15H17V17Z" fill="#3B7AFF"/><path d="M16 18H18V19H16V18Z" fill="#53A3FC"/><path d="M16 15H17V17H16V15Z" fill="#53A3FC"/>',
            name: "Hmm"
        });
        placeholder[10] = IPunksALot.NamedBytes({
            core: '<path d="M11 18H12V19H11V18Z" fill="#3B7AFF"/><path d="M14 18H15V19H14V18Z" fill="#3B7AFF"/><path d="M12 17H14V18H12V17Z" fill="#3B7AFF"/>',
            name: "Sad"
        });
        placeholder[11] = IPunksALot.NamedBytes({
            core: '<path d="M11 18H12V19H11V18Z" fill="#3B7AFF"/><path d="M17 18H18V19H17V18Z" fill="#3B7AFF"/><path d="M16 18H17V19H16V18Z" fill="#53A3FC"/><path d="M12 17H18V18H12V17Z" fill="#3B7AFF"/>',
            name: "Pout"
        });
        placeholder[12] = IPunksALot.NamedBytes({
            core: '<path d="M12 17H15V20H12V17Z" fill="#3B7AFF"/><path d="M13 18H16V19H13V18Z" fill="#303135"/><path d="M16 18H19V19H16V18Z" fill="#52535A"/><path d="M19 18H20V19H19V18Z" fill="#53A3FC"/>',
            name: "Vape"
        });
        placeholder[13] = IPunksALot.NamedBytes({
            core: '<path d="M7 20V16H8V18H9V20H13V19H14V20H17V22H9V21H8V20H7Z" fill="#2F3034"/><path d="M13 18H14V19H13V18Z" fill="#3B7AFF"/>',
            name: "Abe"
        });
        placeholder[14] = IPunksALot.NamedBytes({
            core: '<path d="M9 16H10V17H9V16Z" fill="#DBAEB4"/><path d="M10 9H11V10H10V9Z" fill="#DBAEB4"/><path d="M13 20H14V21H13V20Z" fill="#DBAEB4"/><path d="M16 18H17V19H16V18Z" fill="#DBAEB4"/><path d="M8 20H9V21H8V20Z" fill="#DBAEB4"/><path d="M12 17H14V18H12V17Z" fill="#3B7AFF"/><path d="M17 18H18V19H17V18Z" fill="#3B7AFF"/>',
            name: "Pimples"
        });
        punksALot.addArt(3, placeholder);
    }

    function _addEyes() internal {
        IPunksALot.NamedBytes[] memory placeholder = new IPunksALot.NamedBytes[](11);
        placeholder[0] = IPunksALot.NamedBytes({
            core: '<path d="M11 13H8V14H12V12H11V13Z" fill="#3B7AFF"/><path d="M17 13H14V14H18V12H17V13Z" fill="#3B7AFF"/><path d="M9 12H11V13H9V12Z" fill="#303135"/><path d="M8 12H9V13H8V12Z" fill="#CEDFFB"/><path d="M14 12H15V13H14V12Z" fill="#CEDFFB"/><path d="M15 12H17V13H15V12Z" fill="#303135"/>',
            name: "Angry Squint"
        });
        placeholder[1] = IPunksALot.NamedBytes({
            core: '<path d="M14 14V13H17V12H14V11H18V14H14Z" fill="#3B7AFF"/><path d="M12 14V13H9V14H12Z" fill="#3B7AFF"/><path d="M9 12H12V11H9V12Z" fill="#3B7AFF"/><path d="M9 12H11V13H9V12Z" fill="#CEDFFB"/><path d="M14 12H16V13H14V12Z" fill="#CEDFFB"/><path d="M11 12H12V13H11V12Z" fill="#303135"/><path d="M16 12H17V13H16V12Z" fill="#303135"/>',
            name: "Side Eye"
        });
        placeholder[2] = IPunksALot.NamedBytes({
            core: '<path d="M9 11H11V12H9V11Z" fill="#3B7AFF"/><path d="M11 12H10V13H11V12Z" fill="#303135"/><path d="M10 12H9V13H10V12Z" fill="#CEDFFB"/><path d="M14 11H16V12H14V11Z" fill="#3B7AFF"/><path d="M15 12H16V13H15V12Z" fill="#303135"/><path d="M14 12H15V13H14V12Z" fill="#CEDFFB"/>',
            name: "Looking"
        });
        placeholder[3] = IPunksALot.NamedBytes({
            core: '<path d="M9 12V13H8V11H9V10H11V9H12V12H9Z" fill="#CEDFFB"/><path d="M13 12V9H14V10H16V11H17V13H16V12H13Z" fill="#CEDFFB"/><path d="M8 13H11V14H8V13Z" fill="#3B7AFF"/><path d="M14 13H17V14H14V13Z" fill="#3B7AFF"/><path d="M17 10H18V12H17V10Z" fill="#3B7AFF"/><path d="M9 12H10V13H9V12Z" fill="#82BCFC"/><path d="M10 12H11V13H10V12Z" fill="#303135"/><path d="M15 12H16V13H15V12Z" fill="#303135"/><path d="M14 12H15V13H14V12Z" fill="#82BCFC"/><path d="M16 10H17V11H16V10Z" fill="#53A3FC"/>',
            name: "Thick Eyebrows"
        });
        placeholder[4] = IPunksALot.NamedBytes({
            core: '<path d="M8 11H11V12H8V11Z" fill="#3B7AFF"/><path d="M15 11H18V12H15V11Z" fill="#3B7AFF"/><path d="M14 12H15V13H14V12Z" fill="#3B7AFF"/><path d="M11 12H12V13H11V12Z" fill="#3B7AFF"/><path d="M10 12H11V13H10V12Z" fill="#303135"/><path d="M16 12H17V13H16V12Z" fill="#303135"/><path d="M15 12H16V13H15V12Z" fill="#CEDFFB"/><path d="M9 12H10V13H9V12Z" fill="#CEDFFB"/>',
            name: "Angry Side Eye"
        });
        placeholder[5] = IPunksALot.NamedBytes({
            core: '<path d="M9 12V11H11V10H12V12H9Z" fill="#3B7AFF"/><path d="M17 12H14V10H15V11H17V12Z" fill="#3B7AFF"/><path d="M8 12H9V14H8V12Z" fill="#3B7AFF"/><path d="M9 12H10V14H9V12Z" fill="#303135"/><path d="M10 12H12V14H10V12Z" fill="#CEDFFB"/><path d="M15 12H17V14H15V12Z" fill="#CEDFFB"/><path d="M14 12H15V14H14V12Z" fill="#303135"/><path d="M17 12H18V14H17V12Z" fill="#3B7AFF"/>',
            name: "Not Me"
        });
        placeholder[6] = IPunksALot.NamedBytes({
            core: '<path d="M9 12H10V14H9V12Z" fill="#CEDFFB"/><path d="M17 11H18V15H17V11Z" fill="#3B7AFF"/><path d="M16 11H17V12H16V11Z" fill="#53A3FC"/><path d="M16 14H17V15H16V14Z" fill="#53A3FC"/><path d="M10 12H12V14H10V12Z" fill="#303135"/><path d="M15 12H17V14H15V12Z" fill="#303135"/><path d="M14 12H15V14H14V12Z" fill="#CEDFFB"/>',
            name: "Dilated"
        });
        placeholder[7] = IPunksALot.NamedBytes({
            core: '<path d="M9 11H11V12H9V11Z" fill="#CEDFFB"/><path d="M9 11H11V12H9V11Z" fill="#3B7AFF"/><path d="M14 11H16V12H14V11Z" fill="#3B7AFF"/><path d="M13 12H14V13H13V12Z" fill="#3B7AFF"/><path d="M11 12H12V13H11V12Z" fill="#3B7AFF"/><path d="M10 12H11V13H10V12Z" fill="#303135"/><path d="M14 12H15V13H14V12Z" fill="#303135"/><path d="M15 12H16V13H15V12Z" fill="#CEDFFB"/><path d="M9 12H10V13H9V12Z" fill="#CEDFFB"/>',
            name: "Angry"
        });
        placeholder[8] = IPunksALot.NamedBytes({
            core: '<path d="M8 12H5V11H8V10H13V11H14V10H19V15H14V12H13V15H8V12Z" fill="#52535A"/><path d="M9 11H10V14H9V11Z" fill="#CEDFFB"/><path d="M10 11H12V14H10V11Z" fill="#3B7AFF"/><path d="M16 11H18V14H16V11Z" fill="#3B7AFF"/><path d="M15 11H16V14H15V11Z" fill="#CEDFFB"/>',
            name: "Regular Nouns"
        });
        placeholder[9] = IPunksALot.NamedBytes({
            core: '<path d="M8 12H5V11H8V10H13V11H14V10H19V15H14V12H13V15H8V12Z" fill="#52535A"/><path d="M9 11H12V14H9V11Z" fill="#3B7AFF"/><path d="M15 11H18V14H15V11Z" fill="#3B7AFF"/><path d="M9 12H10V13H9V12Z" fill="#CEDFFB"/><path d="M10 12H12V13H10V12Z" fill="#303135"/><path d="M16 12H18V13H16V12Z" fill="#303135"/><path d="M15 12H16V13H15V12Z" fill="#CEDFFB"/>',
            name: "Tired Nouns"
        });
        placeholder[10] = IPunksALot.NamedBytes({
            core: '<path d="M8 12H6V11H13V12H12V15H9V14H8V12Z" fill="#303135"/><path d="M13 10H16V11H13V10Z" fill="#303135"/><path d="M16 9H17V10H16V9Z" fill="#303135"/><path d="M15 12H16V13H15V12Z" fill="#303135"/><path d="M14 12H15V13H14V12Z" fill="#CEDFFB"/>',
            name: "Eye Patch"
        });
        punksALot.addArt(4, placeholder);
    }
}
