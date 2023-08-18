const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("BidBoard", function () {
	let weth;
	let erc721Mock;
	let bidBoard;

	let owner;
	let addr1;

	beforeEach(async () => {

		// CONTRACTS

		const WETH = await ethers.getContractFactory("WETH");
		weth = await WETH.deploy(1000000000000000);

		const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
		erc721Mock = await ERC721Mock.deploy();

        const BidBoard = await ethers.getContractFactory("BidBoard");
        bidBoard = await BidBoard.deploy(await weth.getAddress());

		// CONFIGS

		[owner, addr1] = await ethers.getSigners();

		await erc721Mock.setApprovalForAll(await bidBoard.getAddress(), true);
		await erc721Mock.connect(addr1).setApprovalForAll(await bidBoard.getAddress(), true);

		await weth.approve(await bidBoard.getAddress(), 1000000000000000);
		await weth.connect(addr1).approve(await bidBoard.getAddress(), 1000000000000000);
    });

	it("BidBoard", async () => {
		await erc721Mock.mint(addr1.address, 0);
		await bidBoard.placeBid(await erc721Mock.getAddress(), 0, 100000);
	});
});
