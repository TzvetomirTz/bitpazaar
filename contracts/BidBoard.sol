// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import { Position } from "./types/Position.sol";

contract BidBoard {
    
    //VARIABLES

    mapping(address => mapping(uint256 => Position)) private bids; // erc721Addr -> tokenId -> position

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
        // ToDo
        
        emit BidPlaced(nftContract, tokenId, "ETHW", amount);
    }
}
