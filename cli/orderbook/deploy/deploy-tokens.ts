import {
  executeTx,
  deployContract,
} from "../../helper";
import { task } from "hardhat/config";
import { WETH9_ADDRESS } from "../../helper/constants";

task(
  "deploy-tokens",
  "Deploy tokens for setting up the market and distribute to accounts"
).setAction(async ({}, { ethers }) => {
  const [deployer, trader1, trader2, booker] = await ethers.getSigners();
  const hre = require("hardhat");
  // Get before state
  console.log(
    `Deployer balance: ${ethers.utils.formatEther(
      await deployer.getBalance()
    )} ETH`
  );

  // Deploy two test tokens with same decimals
  const Token = await ethers.getContractFactory("MockToken");
  const token1 = await Token.deploy("Token1", "TK1");
  await deployContract(token1, "Token1");
  await hre.tenderly.persistArtifacts({
    name: "MockToken",
    address: token1.address,
  });
  const token2 = await Token.deploy("Token2", "TK2");
  await deployContract(token2, "Token2");

  await hre.tenderly.persistArtifacts({
    name: "MockToken",
    address: token2.address,
  });

  // Deploy Fee Token (STND)
  const feeToken = await Token.deploy("FeeToken", "FEE");
  await deployContract(feeToken, "FeeToken");

  await hre.tenderly.persistArtifacts({
    name: "MockToken",
    address: feeToken.address,
  });

  // mint token1 to deployer, trader1, trader2
  const token1MintToDeployer = await token1.mint(
    deployer.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token1MintToDeployer, "Execute mint at");
  const token1MintToTrader1 = await token1.mint(
    trader1.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token1MintToTrader1, "Execute mint at");
  const token1MintToTrader2 = await token1.mint(
    trader2.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token1MintToTrader2, "Execute mint at");
  // mint token2 to deployer, trader1, trader2
  const token2MintToDeployer = await token2.mint(
    deployer.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token2MintToDeployer, "Execute mint at");
  const token2MintToTrader1 = await token2.mint(
    trader1.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token2MintToTrader1, "Execute mint at");
  const token2MintToTrader2 = await token2.mint(
    trader2.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(token2MintToTrader2, "Execute mint at");

  // mint fee token to booker
  const feeTokenMintToBooker = await feeToken.mint(
    booker.address,
    ethers.utils.parseEther("1000000")
  );
  await executeTx(feeTokenMintToBooker, "Execute mint at");
});


