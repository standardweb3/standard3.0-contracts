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

    // Deploy two tokens with same decimals
    const Token = await ethers.getContractFactory("MockToken");
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

    // Deploy Matching Engine
    const MatchingEngine = await ethers.getContractFactory("MatchingEngine");
    const matchingEngine = await MatchingEngine.deploy();
    await deployContract(matchingEngine, "MatchingEngine");



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

    const Orderbook = await ethers.getContractFactory("Orderbook");
    const orderbook = await Orderbook.deploy();
    await deployContract(orderbook, "Orderbook");

    const initOrderbook = await orderbook.initialize(
      token1.address,
      token2.address,
      matchingEngine.address
    );
    await executeTx(initOrderbook, "Initialize Orderbook at");

    
    // initialize Matching Engine
    const initMatchingEngine = await matchingEngine.initialize(
      orderbook.address
    );

    await executeTx(initMatchingEngine, "Initialize Matching Engine at");

    const orderbookR = await matchingEngine.test();
    console.log(orderbookR, "sdfsdfsdf")


    for(var i =0 ; i < 1; i++) {
      console.log(i);
      const limitSell = await matchingEngine.limitSell(
        token1.address,
        token2.address,
        ethers.utils.parseEther("2"),
        100000000,
        true
      );
      await executeTx( limitSell, "limit sell at");
    }

    const limitBuy1 = await matchingEngine.limitBuy(
      token1.address,
      token2.address,
      ethers.utils.parseEther("2"),
      100000000,
      true
    );
    await executeTx( limitBuy1, "limit buy at");
 
    this.matchingEngine = matchingEngine;
    this.token1 = token1;
    this.token2 = token2;
    this.deployer = deployer;
  });

  
 

  it("An orderbook should be able to store bid order and match existing one", async function () {});

  it("An orderbook should be able to bid multiple price orders", async function () {});

  it("An orderbook should be able to ask multiple price orders", async function () {});

  it("An orderbook should match ask orders to bidOrders at lowestBid then lowest bid should be updated after depleting lowest bid orders", async function () {});

  it("An orderbook should match bid orders to askOrders at highestAsk then highest ask should be updated after depleting highest ask orders", async function () {});
});
