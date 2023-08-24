// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// IMPORTS

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Ask } from "./types/Ask.sol";

contract AskBoard is ERC721Holder, Ownable {

    // LIBS

    using SafeERC20 for IERC20;

    //VARIABLES

    uint256 private profit = 0;
    uint16 askFeeBps = 100;
    IERC20 wethContract;
    mapping(address => mapping(uint256 => Ask)) private asks; // erc721Addr -> tokenId -> Ask

    // CONSTRUCTOR
    constructor(address wethContractAddr) {
        wethContract = IERC20(wethContractAddr);
    }

    // EVENTS

    event AskPlaced(address nftContract, uint256 tokenId, uint256 amount);
    event AskCancelled(address nftContract, uint256 tokenId, uint256 amount);
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

        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        asks[nftContract][tokenId] = Ask(msg.sender, amount);

        emit AskPlaced(nftContract, tokenId, amount);
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
        Ask memory currentAsk = asks[nftContract][tokenId];
        require(currentAsk.initiator == msg.sender);

        delete asks[nftContract][tokenId];
        IERC721(nftContract).safeTransferFrom(address(this), currentAsk.initiator, tokenId);

        emit AskCancelled(nftContract, tokenId, currentAsk.amount);
    }

    /**
     * @dev Returns the current ask for the token with id `tokenId` in the `nftContract` NFT contract.
     *
     * Requirements:
     *
     * - `nftContract` has to be a valid ERC721 implementation.
     * - `tokenId` has to be a valid token id for the given ERC721.
     */
    function getCurrentAsk(address nftContract, uint256 tokenId) public view returns (uint256 _amount, address _askOwner) {
        Ask memory ask = asks[nftContract][tokenId];
        return (ask.amount, ask.initiator);
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
        Ask memory currentAsk = asks[nftContract][tokenId];
        require(currentAsk.initiator != address(0), "Ask is not present.");
        require(currentAsk.amount == amount, "Current ask amount doesn't match the requested one."); // Prevents front running and old tx execution.

        delete asks[nftContract][tokenId];
        uint256 fee = (amount * askFeeBps) / 10000;
        wethContract.safeTransferFrom(msg.sender, address(this), currentAsk.amount + fee);
        wethContract.safeTransfer(currentAsk.initiator, currentAsk.amount);
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);

        profit += fee;
        emit AskAccepted(nftContract, tokenId, currentAsk.amount);
    }

    /**
     * @dev Returns the current ask fee bps. This fee is paid by the accepting side, not by the asker.
     */
    function getAskFeeBps() public view returns(uint16 _askFeeBps) {
        return askFeeBps;
    }

    /**
     * @dev Yields all the fees profit and sends it to the owner of the Bid Board.
     */
    function yieldAllProfit() public {
        wethContract.safeTransfer(owner(), profit);
        profit = 0;
    }
}
