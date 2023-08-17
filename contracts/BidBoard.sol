// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Position } from "./types/Position.sol";

contract BidBoard {

    // LIBS

    using SafeERC20 for IERC20;
    
    //VARIABLES

    uint16 bidFeeBps = 100;
    IERC20 wethContract;
    mapping(address => mapping(uint256 => Position)) private bids; // erc721Addr -> tokenId -> position

    // CONSTRUCTOR
    constructor(address wethContractAddr) {
        wethContract = IERC20(wethContractAddr);
    }

    // EVENTS

    event BidPlaced(address nftContract, uint256 tokenId, string currency, uint256 amount);

    // PUBLIC FUNCTIONS

    /**
     * @dev Places a bid by the caller for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` .
     * - msg.value has to be greater than 0.
     */
    function placeBid(address nftContract, uint256 tokenId, uint256 amount) public payable {
        uint256 fee = (amount / 10000) * bidFeeBps;
        require(msg.value >= fee);

        Position memory currentBid = bids[nftContract][tokenId];
        require(currentBid.initiator == address(0) || currentBid.amount < amount);

        wethContract.transferFrom(msg.sender, address(this), amount);
        bids[nftContract][tokenId] = Position(msg.sender, "WETH", amount, fee);

        emit BidPlaced(nftContract, tokenId, "WETH", amount);
    }
}
