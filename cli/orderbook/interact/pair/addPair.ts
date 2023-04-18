import { executeTx, deployContract, getAddress } from "../../../helper";
import { task } from "hardhat/config";
import { WETH9_ADDRESS } from "../../../helper/constants";
import { ChainId } from "../../../helper/constants";

task("interact-add-pair", "Deploy orderbook")
  .addParam("base", "The Base token contract address")
  .addParam("quote", "The Quote token contract address")
  .addParam("feetoken", "The Fee token contract address")
  .setAction(async ({ base, quote, feetoken }, { ethers }) => {
    const inquirer = require("inquirer");
    const [deployer, trader1, trader2, booker] = await ethers.getSigners();
    const chainId: ChainId = await deployer.getChainId();

    const result = await inquirer.prompt([
      {
        type: "list",
        name: "signer",
        message: "Choose signer",
        choices: [
          deployer.address,
          trader1.address,
          trader2.address,
          booker.address,
        ],
      },
    ]);

    const signer = await ethers.getSigner(result.signer);
    // get balance of fee token from Signer
    const FeeToken = await ethers.getContractFactory("MockToken");
    const feeT = new ethers.Contract(
      feetoken,
      FeeToken.interface,
      ethers.provider
    );
    const feeTokenBalance = await feeT.balanceOf(signer.address);

    // Check if signer has enough FeeToken balance
    if (feeTokenBalance.lt(ethers.utils.parseEther("300"))) {
      throw new Error(`Insufficient FeeToken balance: current balance is ${feeTokenBalance} and required balance is 300 ether`);
    }

    const MatchingEngine = await ethers.getContractFactory("MatchingEngine");
    const matchingEngine = new ethers.Contract(
      await getAddress("MatchingEngine", chainId),
      MatchingEngine.interface
    );

    // Deployer approves matching engine of FeeToken as STND
    const FeeTokenBySigner = await feeT.connect(signer);
    const approveFeeTokenBySigner = await FeeTokenBySigner.approve(
      matchingEngine.address,
      ethers.utils.parseEther("1000000")
    );
    await executeTx(
      approveFeeTokenBySigner,
      "Approve Matching Engine to use FeeToken at"
    );

    // Add WETH, STND base/quote pair to MatchingEngine by signer
    const matchingEngineBySigner = await matchingEngine.connect(signer);
    const addTokenPairBySigner = await matchingEngineBySigner.addPair(
      base,
      quote
    );
    await executeTx(addTokenPairBySigner, "Add token pair at");
  });
