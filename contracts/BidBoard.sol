// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Position } from "./types/Position.sol";

contract BidBoard {

    // LIBS

    using SafeERC20 for IERC20;
    
    //VARIABLES

    uint256 profit = 0;
    uint16 bidFeeBps = 100;
    IERC20 wethContract;
    mapping(address => mapping(uint256 => Position)) private bids; // erc721Addr -> tokenId -> position

    // CONSTRUCTOR
    constructor(address wethContractAddr) {
        wethContract = IERC20(wethContractAddr);
    }

    // EVENTS

    event BidPlaced(address nftContract, uint256 tokenId, uint256 amount, uint256 fee);
    event BidCancelled(address nftContract, uint256 tokenId, uint256 totalRefund);
    event BidAccepted(address nftContract, uint256 tokenId, uint256 amount);

    // PUBLIC FUNCTIONS

    /**
     * @dev Returns the current bidding fee bps.
     */
    function getBiddingFeeBps() public view returns(uint16 _bidFeeBps) {
        return bidFeeBps;
    }

    /**
     * @dev Places a bid by the caller for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     */
    function placeBid(address nftContract, uint256 tokenId, uint256 amount) public {
        uint256 fee = (amount * bidFeeBps) / 10000;
        Position memory currentBid = bids[nftContract][tokenId];
        require(currentBid.initiator == address(0) || currentBid.amount < amount);

        if(currentBid.initiator != address(0)) {
            delete bids[nftContract][tokenId];
            wethContract.safeTransfer(currentBid.initiator, currentBid.amount + currentBid.fee);
        }

        wethContract.safeTransferFrom(msg.sender, address(this), amount + fee);
        bids[nftContract][tokenId] = Position(msg.sender, amount, fee);

        emit BidPlaced(nftContract, tokenId, amount, fee);
    }

    /**
     * @dev Cancels a bid by the caller for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     * - msg.sender has to be the owner of the current bid.
     */
    function cancelBid(address nftContract, uint256 tokenId) public {
        Position memory bid = bids[nftContract][tokenId];
        require(bid.initiator == msg.sender, "Not enough permissions to cancel this bid.");

        delete bids[nftContract][tokenId];
        wethContract.safeTransfer(msg.sender, bid.amount + bid.fee);

        emit BidCancelled(nftContract, tokenId, bid.amount + bid.fee);
    }

    /**
     * @dev Returns the current bid for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     */
    function getCurrentBid(address nftContract, uint256 tokenId) public view returns (uint256 _amount, address _bidOwner) {
        Position memory bid = bids[nftContract][tokenId];
        return (bid.amount, bid.initiator);
    }

    /**
     * @dev Accepts the current bid for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     * - msg.sender has to be the owner of the token.
     * - There has to be an active bid.
     */
    function acceptBid(address nftContract, uint256 tokenId) public {
        Position memory currentBid = bids[nftContract][tokenId];
        require(currentBid.initiator != address(0), "Bid is not present.");

        delete bids[nftContract][tokenId];
        IERC721(nftContract).safeTransferFrom(msg.sender, currentBid.initiator, tokenId);
        wethContract.safeTransfer(msg.sender, currentBid.amount);

        emit BidAccepted(nftContract, tokenId, currentBid.amount);
    }
}
