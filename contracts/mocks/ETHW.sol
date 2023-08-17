// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ETHW is ERC20 {
    constructor(uint256 initialSupply) ERC20("Wrapped Ether", "ETHW") {
        _mint(msg.sender, initialSupply);
    }
}
