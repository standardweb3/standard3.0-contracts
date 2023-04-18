import {
    executeTx,
    deployContract,
    ChainId,
    FACTORY_ROLE,
    getAddress,
    ZERO,
  } from "../../../helper";
  import { task } from "hardhat/config";
  import { WETH9_ADDRESS } from "../../../helper/constants";

task("interact-limit-buy", "Limit buys on orderbook")
  .setAction(async ( { ethers }) => {
    const hre = require("hardhat");
    const inquirer = require("inquirer");
    const { deployer, trader1, trader2, booker } = hre.namedAccounts;

    const signerAddress = await inquirer.prompt([
      {
        type: "list",
        name: "signer",
        message: "Choose signer",
        choices: [deployer, trader1, trader2, booker],
      },
    ]);

    const signer = await ethers.getSigner(signerAddress);

    // Limit Buy on Orderbook
    const orderbook = await ethers.getContractAt(
      "MatchingEngine",
      await getAddress("MatchingEngine", ChainId.LOCALHOST)
    );
    const orderbookBySigner = orderbook.connect(signer);
    orderbookBySigner.limitBuy(
      await getAddress("Token1", ChainId.LOCALHOST),
      await getAddress("Token2", ChainId.LOCALHOST),
      1,
      1,
    )
  });

task("interact-limit-sell", "Limit sells on orderbook")
  .setAction(async ( { ethers }) => {
    const hre = require("hardhat");
    const inquirer = require("inquirer");
    const { trader1, trader2, booker } = hre.namedAccounts;

    const signerAddress = await inquirer.prompt([
      {
        type: "list",
        name: "signer",
        message: "Choose signer",
        choices: [trader1, trader2, booker],
      },
    ]);

    const signer = await ethers.getSigner(signerAddress);

    // Do something with the signer...
  });

task("interact-add-book", "Add another book to orderbook")
  .setAction(async ( { ethers }) => {
    const hre = require("hardhat");
    const inquirer = require("inquirer");
    const { trader1, trader2, booker } = hre.namedAccounts;

    const signerAddress = await inquirer.prompt([
      {
        type: "list",
        name: "signer",
        message: "Choose signer",
        choices: [trader1, trader2, booker],
      },
    ]);

    const signer = await ethers.getSigner(signerAddress);

    // Do something with the signer...
  });
