// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

struct Bid {
    address initiator;
    uint256 amount;
    uint256 fee;
    uint256 originBlock;
}
