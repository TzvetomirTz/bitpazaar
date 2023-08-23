const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("BidBoard", function () {
	const zeroAddr = "0x0000000000000000000000000000000000000000";

	let weth;
	let bidBoard;
	let erc721Mock;

	let wethAddr;
	let bidBoardAddr;
	let erc721Addr;

	let owner;
	let addr1;
	let addr2;

	let bidFeeBps;

	beforeEach(async () => {

		// CONTRACTS

		const WETH = await ethers.getContractFactory("WETH");
		weth = await WETH.deploy(1000000000000000);
		wethAddr = await weth.getAddress();

        const BidBoard = await ethers.getContractFactory("BidBoard");
        bidBoard = await BidBoard.deploy(wethAddr);
		bidBoardAddr = await bidBoard.getAddress();

		const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
		erc721Mock = await ERC721Mock.deploy();
		erc721Addr = await erc721Mock.getAddress();

		// CONFIGS

		[owner, addr1, addr2] = await ethers.getSigners();

		await erc721Mock.setApprovalForAll(bidBoardAddr, true);
		await erc721Mock.connect(addr1).setApprovalForAll(bidBoardAddr, true);
		await erc721Mock.connect(addr2).setApprovalForAll(bidBoardAddr, true);

		await weth.approve(bidBoardAddr, 1000000000000000);
		await weth.connect(addr1).approve(bidBoardAddr, 1000000000000000);
		await weth.connect(addr2).approve(bidBoardAddr, 1000000000000000);

		bidFeeBps = Number(await bidBoard.getBiddingFeeBps());
    });

	it("Bid placement and cancellation", async () => {
		await erc721Mock.mint(addr1.address, 0);
		const amount = 100000;
		const fee = (amount * bidFeeBps) / 10000;

		const ownerInitBalance = Number(await weth.balanceOf(owner));
		const bidBoardInitBalance = Number(await weth.balanceOf(bidBoardAddr));

		await bidBoard.placeBid(erc721Addr, 0, amount);
		let currentBid = await bidBoard.getCurrentBid(erc721Addr, 0);
		
		expect(Number(currentBid[0])).to.equal(amount);
		expect(await weth.balanceOf(owner)).to.equal(ownerInitBalance - (amount + fee));
		expect(await weth.balanceOf(bidBoardAddr)).to.equal(amount + fee);

		await bidBoard.cancelBid(erc721Addr, 0);
		expect(await weth.balanceOf(owner)).to.equal(ownerInitBalance);
		expect(await weth.balanceOf(bidBoardAddr)).to.equal(bidBoardInitBalance);
	});

	it("Bid placement and acceptance", async () => {
		await erc721Mock.mint(addr1.address, 0);
		const amount = 100000;
		const fee = (amount * bidFeeBps) / 10000;

		const ownerInitBalance = Number(await weth.balanceOf(owner));

		await bidBoard.placeBid(erc721Addr, 0, amount);
		expect(await weth.balanceOf(bidBoardAddr)).to.equal(amount + fee);
		expect(bidBoard.acceptBid(erc721Addr, 0, amount)).to.be.reverted;
		await bidBoard.connect(addr1).acceptBid(erc721Addr, 0, amount);

		expect(await weth.balanceOf(owner)).to.equal(ownerInitBalance - (amount + fee));
		expect(await weth.balanceOf(bidBoardAddr)).to.equal(fee);
		expect(await weth.balanceOf(addr1)).to.equal(amount);
		expect(await erc721Mock.ownerOf(0)).to.equal(owner.address);
	});

	it("Bid placement and bid overwrite", async () => {
		await erc721Mock.mint(owner.address, 0);
		const amount1 = 10000;
		const amount2 = 100000;
		const fee1 = (amount1 * bidFeeBps) / 10000;
		const fee2 = (amount2 * bidFeeBps) / 10000;

		await weth.transfer(addr1, 20000);
		await weth.transfer(addr2, 200000);

		const addr1InitBalance = Number(await weth.balanceOf(addr1));
		const addr2InitBalance = Number(await weth.balanceOf(addr2));

		await bidBoard.connect(addr1).placeBid(erc721Addr, 0, amount1);
		expect(await weth.balanceOf(addr1)).to.equal(addr1InitBalance - (amount1 + fee1));

		await bidBoard.connect(addr2).placeBid(erc721Addr, 0, amount2);
		expect(await weth.balanceOf(addr1)).to.equal(addr1InitBalance);
		expect(await weth.balanceOf(addr2)).to.equal(addr2InitBalance - (amount2 + fee2));
	});
});
