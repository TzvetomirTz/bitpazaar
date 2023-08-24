const { expect } = require('chai');
const { ethers } = require('hardhat');

describe("AskBoard", function () {
	const zeroAddr = "0x0000000000000000000000000000000000000000";

	let weth;
	let askBoard;
	let erc721Mock;

	let wethAddr;
	let askBoardAddr;
	let erc721Addr;

	let owner;
	let addr1;
	let addr2;

	let askFeeBps;

	beforeEach(async () => {

		// CONTRACTS

		const WETH = await ethers.getContractFactory("WETH");
		weth = await WETH.deploy(1000000000000000);
		wethAddr = await weth.getAddress();

        const AskBoard = await ethers.getContractFactory("AskBoard");
        askBoard = await AskBoard.deploy(wethAddr);
		askBoardAddr = await askBoard.getAddress();

		const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
		erc721Mock = await ERC721Mock.deploy();
		erc721Addr = await erc721Mock.getAddress();

		// CONFIGS

		[owner, addr1, addr2] = await ethers.getSigners();

		await erc721Mock.setApprovalForAll(askBoardAddr, true);
		await erc721Mock.connect(addr1).setApprovalForAll(askBoardAddr, true);
		await erc721Mock.connect(addr2).setApprovalForAll(askBoardAddr, true);

		await weth.approve(askBoardAddr, 1000000000000000);
		await weth.connect(addr1).approve(askBoardAddr, 1000000000000000);
		await weth.connect(addr2).approve(askBoardAddr, 1000000000000000);

		askFeeBps = Number(await askBoard.getAskFeeBps());
    });

    it("Ask placement and cancellation", async () => {
		await erc721Mock.mint(owner.address, 0);

		expect(askBoard.connect(addr1).placeAsk(erc721Addr, 0, 100000)).to.be.reverted;
		await askBoard.placeAsk(erc721Addr, 0, 100000);
		expect(await erc721Mock.ownerOf(0)).to.equal(askBoardAddr);

		expect(askBoard.connect(addr1).cancelAsk(erc721Addr, 0)).to.be.reverted;
		await askBoard.cancelAsk(erc721Addr, 0);
		expect(await erc721Mock.ownerOf(0)).to.equal(owner.address);
	});

	it("Ask placement and acceptance", async () => {
		await erc721Mock.mint(owner.address, 0);
		const amount = 100000;
		const fee = (amount * askFeeBps) / 10000;
		await weth.transfer(addr1, 200000);

		const ownerInitBalance = Number(await weth.balanceOf(owner));
		const addr1InitBalance = Number(await weth.balanceOf(addr1));

		expect(askBoard.connect(addr1).placeAsk(erc721Addr, 0, amount)).to.be.reverted;
		await askBoard.placeAsk(erc721Addr, 0, amount);
		expect(await erc721Mock.ownerOf(0)).to.equal(askBoardAddr);

		await askBoard.connect(addr1).acceptAsk(erc721Addr, 0, amount);
		expect(Number(await weth.balanceOf(owner))).to.equal(ownerInitBalance + amount);
		expect(Number(await weth.balanceOf(addr1))).to.equal(addr1InitBalance - (amount + fee));
		expect(Number(await weth.balanceOf(askBoardAddr))).to.equal(fee);
		expect(await erc721Mock.ownerOf(0)).to.equal(addr1.address);
	});
});