// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Position } from "./types/Position.sol";

contract AskBoard {

    // LIBS

    using SafeERC20 for IERC20;
    
    //VARIABLES

    uint16 askFeeBps = 100;
    IERC20 wethContract;
    mapping(address => mapping(uint256 => Position)) private asks; // erc721Addr -> tokenId -> position

    // CONSTRUCTOR
    constructor(address wethContractAddr) {
        wethContract = IERC20(wethContractAddr);
    }

    // EVENTS

    event AskPlaced(address nftContract, uint256 tokenId, uint256 amount, uint256 fee);
    event AskCancelled(address nftContract, uint256 tokenId, uint256 amount, uint256 fee);
    event AskAccepted(address nftContract, uint256 tokenId, uint256 amount);

    /**
     * @dev Places an ask by the caller for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     * - msg.sender has to be the owner of the given token.
     */
    function placeAsk(address nftContract, uint256 tokenId, uint256 amount) public {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender);
        uint256 fee = (amount * askFeeBps) / 10000;

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        asks[nftContract][tokenId] = Position(msg.sender, amount, fee);

        emit AskPlaced(nftContract, tokenId, amount, fee);
    }

    /**
     * @dev Cancels an ask by the caller for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     * - msg.sender has to be the owner of the placed ask.
     */
    function cancelAsk(address nftContract, uint256 tokenId) public {
        Position memory currentAsk = asks[nftContract][tokenId];
        require(currentAsk.initiator == msg.sender);

        delete asks[nftContract][tokenId];
        IERC721(nftContract).safeTransferFrom(address(this), currentAsk.initiator, tokenId);

        emit AskCancelled(nftContract, tokenId, currentAsk.amount, currentAsk.fee);
    }

    /**
     * @dev Returns the current ask for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     */
    function getCurrentAsk(address nftContract, uint256 tokenId) public view returns (uint256 _amount, uint256 _fee, address _askOwner) {
        Position memory ask = asks[nftContract][tokenId];
        return (ask.amount, ask.fee, ask.initiator);
    }

    /**
     * @dev Accepts the current ask for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     * - There has to be an active ask.
     */
    function acceptAsk(address nftContract, uint256 tokenId, uint256 amount) public {
        Position memory currentAsk = asks[nftContract][tokenId];
        require(currentAsk.initiator != address(0), "Ask is not present.");
        require(currentAsk.amount == amount, "Current ask amount doesn't match the requested one."); // Prevents front running and old tx execution.

        delete asks[nftContract][tokenId];
        wethContract.safeTransferFrom(msg.sender, address(this), currentAsk.amount + currentAsk.fee);
        wethContract.safeTransfer(currentAsk.initiator, currentAsk.amount);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        emit AskAccepted(nftContract, tokenId, currentAsk.amount);
    }
}
