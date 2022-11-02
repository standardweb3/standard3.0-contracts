import {
  executeTx,
  deployContract,
  ChainId,
  FACTORY_ROLE,
  getAddress,
  ZERO,
} from "../helper";
import { task } from "hardhat/config";
import { WETH9_ADDRESS } from "@digitalnative/standard-protocol-sdk"

  task("orderbook-deploy", "Deploy orderbook")
  .addOptionalParam("manager", "old manager contract address")
  .addOptionalParam("factory", "old factory contract address")
  .setAction(async ({ manager, factory }, { ethers }) => {
    const [deployer] = await ethers.getSigners();
    const hre = require("hardhat")
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
    await hre.tenderly.persistArtifacts({
      name: "MockToken",
      address:token1.address
    });
    const token2 = await Token.deploy("Token2", "TK2");
    await deployContract(token2, "Token2");

    await hre.tenderly.persistArtifacts({
      name: "MockToken",
      address:token2.address
    });

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

    await hre.tenderly.persistArtifacts({
      name: "MatchingEngine",
      address:token1.address
    });


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
    await hre.tenderly.persistArtifacts({
      name: "Orderbook",
      address:token1.address
    });
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
 
    await hre.run("verify:verify", {
      address: matchingEngine.address
    });

    await hre.run("verify:verify", {
      address: orderbook.address
    });

  });

