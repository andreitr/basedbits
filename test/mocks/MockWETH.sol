// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

/// @dev Minimal WETH9-style mock: deposit/withdraw plus mint for test setup.
contract MockWETH is ERC20 {
    constructor() ERC20("Mock WETH", "WETH") {}

    receive() external payable {
        _mint(msg.sender, msg.value);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "MockWETH: withdraw failed");
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
