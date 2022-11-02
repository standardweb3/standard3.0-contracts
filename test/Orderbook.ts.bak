import { exec } from "child_process";
import { assert } from "console";
import { FACTORY_ROLE, ZERO } from "../cli/helper";
import { executeTx, deployContract, ChainId, getAddress } from "./helper";
const { EtherscanProvider } = require("@ethersproject/providers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  now,
  mine,
  setTime,
  setTimeAndMine,
  Ganache,
  impersonate,
  skipBlocks,
  stopMining,
  startMining,
  addToBlock,
} = require("./helpers");

const expectArray = (actual, expected) => {
  for (let i = 0; i < actual.length; i++) {
    expect(actual[i].toString()).to.equal(expected[i].toString());
  }
};

describe("Basic Operations", function () {
  before(async function () {
    // setup the whole contracts
    const [deployer] = await ethers.getSigners();

    // Get before state
    console.log(
      `Deployer balance: ${ethers.utils.formatEther(
        await deployer.getBalance()
      )} ETH`
    );

    // Deploy two tokens
    const Token = await ethers.getContractFactory("ERC20PresetMinterPauser");
    const token1 = await Token.deploy("Token1", "TK1");
    await deployContract(token1, "Token1");
    const token2 = await Token.deploy("Token2", "TK2");
    await deployContract(token2, "Token2");

    // mint tokens for test
    const token1Mint = await token1.mint(
      deployer.address,
      ethers.utils.parseEther("1000000")
    );
    await executeTx(token1Mint, "Execute mint at");
    const token2Mint = await token2.mint(
      deployer.address,
      ethers.utils.parseEther("1000000")
    );
    await executeTx(token2Mint, "Execute mint at");

    // Deploy libraries
    const NewOrderLinkedList = await ethers.getContractFactory("NewOrderLinkedList");
    const newOrderLinkedList = await NewOrderLinkedList.deploy();
    await deployContract(newOrderLinkedList, "NewOrderLinkedList");

    const NewOrderQueue = await ethers.getContractFactory("NewOrderQueue");
    const newOrderQueue = await NewOrderQueue.deploy();
    await deployContract(newOrderQueue, "NewOrderQueue");

    // Deploy OrderbookFactory
    const OrderbookFactory = await ethers.getContractFactory(
      "OrderbookFactory", //{libraries: {
        //NewOrderLinkedList: newOrderLinkedList.address,
        // NewOrderQueue: newOrderQueue.address,
      //}}
    );
    const orderbookFactory = await OrderbookFactory.deploy();
    await deployContract(orderbookFactory, "OrderbookFactory");

    // Deploy Matching Engine
    const MatchingEngine = await ethers.getContractFactory("MatchingEngine");
    const matchingEngine = await MatchingEngine.deploy();
    await deployContract(matchingEngine, "MatchingEngine");

    // initialize Matching Engine
    const initMatchingEngine = await matchingEngine.initialize(
      orderbookFactory.address
    );

    await executeTx(initMatchingEngine, "Initialize Matching Engine at");

    // initialize Orderbook Factory
    const initOrderbookFactory = await orderbookFactory.initialize(
      matchingEngine.address
    );

    await executeTx(initOrderbookFactory, "Initialize Orderbook Factory at");

    // Approve Matching Engine to use tokens
    const approveToken1 = await token1.approve(
      matchingEngine.address,
      ethers.utils.parseEther("1000000")
    );
    await executeTx(approveToken1, "Approve Matching Engine to use Token1 at");
    const approveToken2 = await token2.approve(
      matchingEngine.address,
      ethers.utils.parseEther("1000000")
    );
    await executeTx(approveToken2, "Approve Matching Engine to use Token2 at");

    // set fee to random address other than deployer on Matching Engine fee
    const setFee = await matchingEngine.setFeeTo("0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC");
    await executeTx(setFee, "Set feeTo to zero at");

    this.matchingEngine = matchingEngine;
    this.orderbookFactory = orderbookFactory;
    this.token1 = token1;
    this.token2 = token2;
    this.deployer = deployer;
  });

  it("A orderbook should be able to open a book between two tokens", async function () {
    // create a orderbook
    const addBook = await this.matchingEngine.addBook(
      this.token1.address,
      this.token2.address
    );
    await executeTx(addBook, "Create orderbook at");

    const orderbookAddress = await this.matchingEngine.getOrderbook("0");
    const orderbook = await ethers.getContractAt("Orderbook", orderbookAddress);
    const baseQuote = await this.orderbookFactory.getBaseQuote(orderbook.address);
    expect(baseQuote[0]).to.equal(this.token1.address);
    expect(baseQuote[1]).to.equal(this.token2.address);

    // Once an orderbook is set between pair, you cannot add another vice versa
  });

  it("An orderbook should be able to store bid limit order", async function () {
    const before = await this.token1.balanceOf(this.deployer.address);
    // <base>/<quote>(<token1>/<token2>) = 1.00000000
    const limitSell1 = await this.matchingEngine.limitSell(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitSell2 = await this.matchingEngine.limitSell(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitSell3 = await this.matchingEngine.limitSell(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitSell4 = await this.matchingEngine.limitSell(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitSell5 = await this.matchingEngine.limitSell(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    await executeTx(limitSell1, "limit sell at");
    await executeTx(limitSell2, "limit sell at");
    await executeTx(limitSell3, "limit sell at");
    await executeTx(limitSell4, "limit sell at");
    await executeTx(limitSell5, "limit sell at");
    const after = await this.token1.balanceOf(this.deployer.address);
    expect(before.sub(after).toString()).to.equal(
      ethers.utils.parseEther("1000").toString()
    );
  });

  it("An orderbook should be able to store ask limit order and match existing one", async function () {
    const before = await this.token1.balanceOf(this.deployer.address);
    const limitBuy1 = await this.matchingEngine.limitBuy(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitBuy2 = await this.matchingEngine.limitBuy(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitBuy3 = await this.matchingEngine.limitBuy(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitBuy4 = await this.matchingEngine.limitBuy(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    const limitBuy5 = await this.matchingEngine.limitBuy(
      this.token1.address,
      this.token2.address,
      ethers.utils.parseEther("200"),
      100000000,
      true
    );
    
    await executeTx(limitBuy1, "Limit buy at");
    await executeTx(limitBuy2, "Limit buy at");
    await executeTx(limitBuy3, "Limit buy at");
    await executeTx(limitBuy4, "Limit buy at");
    await executeTx(limitBuy5, "Limit buy at");
    const after = await this.token1.balanceOf(this.deployer.address);
    //const mktPrice = await this.matchingEngine.mktPrice();
    expect(after.sub(before).toString()).to.equal(
      ethers.utils.parseEther("0").toString()
    );
    //expect(mktPrice.toString()).to.equal("100000000");
  });

  it("An orderbook should be able to store bid order and match existing one", async function () {});

  it("An orderbook should be able to bid multiple price orders", async function () {});

  it("An orderbook should be able to ask multiple price orders", async function () {});

  it("An orderbook should match ask orders to bidOrders at lowestBid then lowest bid should be updated after depleting lowest bid orders", async function () {});

  it("An orderbook should match bid orders to askOrders at highestAsk then highest ask should be updated after depleting highest ask orders", async function () {});
});
