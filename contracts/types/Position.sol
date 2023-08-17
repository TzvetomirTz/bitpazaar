// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

struct Position {
    address initiator;
    string currency;
    uint256 amount;
    uint256 fee;
}