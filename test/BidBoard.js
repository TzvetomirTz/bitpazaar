const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("BidBoard", function () {
	let bidBoard;
	let weth;

	beforeEach(async () => {
		const WETH = await ethers.getContractFactory("ETHW");
		weth = await WETH.deploy();

        const BidBoard = await ethers.getContractFactory("BidBoard");
        bidBoard = await BidBoard.deploy(await weth.getAddress());
    });
});
