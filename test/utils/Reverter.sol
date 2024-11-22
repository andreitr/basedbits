// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract Reverter is ERC20 {
    constructor() ERC20("REV", "Reverter") {}

    receive() external payable {
        revert();
    }

    function caller(address _to, bytes calldata _data) external {
        (bool s,) = _to.call(_data);
        assert(s);
    }
}
