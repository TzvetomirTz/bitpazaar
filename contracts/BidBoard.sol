// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Bid } from "./types/Bid.sol";

contract BidBoard is Ownable {

    // LIBS

    using SafeERC20 for IERC20;
    
    //VARIABLES

    uint256 private profit = 0;                 // full slot
    IERC20 private wethContract;                // 160/256 bits
    uint32 private minBlocksToCancelBid = 600;  // 192/256 bits
    uint16 private bidFeeBps = 100;             // 208/256 bits
    mapping(address => mapping(uint256 => Bid)) private bids; // erc721Addr -> tokenId -> Bid

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
    function getBidFeeBps() public view returns(uint16 _bidFeeBps) {
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
        Bid memory currentBid = bids[nftContract][tokenId];
        require(currentBid.initiator == address(0) || currentBid.amount < amount);

        if(currentBid.initiator != address(0)) {
            delete bids[nftContract][tokenId];
            wethContract.safeTransfer(currentBid.initiator, currentBid.amount + currentBid.fee);
        }

        wethContract.safeTransferFrom(msg.sender, address(this), amount + fee);
        bids[nftContract][tokenId] = Bid(msg.sender, amount, fee, block.number);

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
        Bid memory bid = bids[nftContract][tokenId];
        require(bid.initiator == msg.sender, "Not enough permissions to cancel this bid.");
        require(block.number - bid.originBlock >= minBlocksToCancelBid, "Bid cannot be cancelled yet.");

        delete bids[nftContract][tokenId];
        wethContract.safeTransfer(msg.sender, bid.amount + bid.fee);

        emit BidCancelled(nftContract, tokenId, bid.amount + bid.fee);

        // TODO: add minimum of blocks mined interval to keep a bid before cancellation availability.
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
        Bid memory bid = bids[nftContract][tokenId];
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
    function acceptBid(address nftContract, uint256 tokenId, uint256 amount) public {
        Bid memory currentBid = bids[nftContract][tokenId];
        require(currentBid.initiator != address(0), "Bid is not present.");
        require(currentBid.amount == amount, "Current bid amount doesn't match the requested one."); // Prevents front running and old tx execution.

        delete bids[nftContract][tokenId];
        IERC721(nftContract).safeTransferFrom(msg.sender, currentBid.initiator, tokenId);
        wethContract.safeTransfer(msg.sender, currentBid.amount);
        profit += currentBid.fee;

        emit BidAccepted(nftContract, tokenId, currentBid.amount);
    }

    /**
     * @dev Yields all the fees profit and sends it to the owner of the Bid Board.
     */
    function yieldAllProfit() public {
        wethContract.safeTransfer(owner(), profit);
        profit = 0;
    }

    /**
     * @dev Changes the minimum blocks mining wait time to allow someone to cancel their bid.
     *
     * Requirements:
     * msg.sender has to be the owner of the Bid Board.
     */
    function updateMinBlocksToCancelBid(uint32 newWait) public onlyOwner {
        minBlocksToCancelBid = newWait;
    }

    /**
     * @dev Returns the minimum blocks mining wait time to allow someone to cancel their bid.
     */
    function getMinBlocksToCancelBid() public view returns(uint32 _minBlocksToCancelBid) {
        return minBlocksToCancelBid;
    }
}
