import { executeTx, deployContract, getAddress } from "../../helper";
import { task } from "hardhat/config";
import { WETH9_ADDRESS } from "../../helper/constants";
import { ChainId } from "../../helper/constants";

task("deploy-orderbook", "Deploy orderbook")
  .addOptionalParam("env", "The network to run the deployment on", "localhost")
  .setAction(async ({ env }, { ethers }) => {
    const [deployer, trader1, trader2, booker] = await ethers.getSigners();

    if (env === "localhost") {
      // Get token1, token2, feeToken from deploy-tokens.ts in address-book.json
      const Token = await ethers.getContractFactory("MockToken");
      console.log(await getAddress("Token1", ChainId.LOCALHOST));
      const token1 = new ethers.Contract(
        await getAddress("Token1", ChainId.LOCALHOST),
        Token.interface
      );
      const token2 = new ethers.Contract(
        await getAddress("Token2", ChainId.LOCALHOST),
        Token.interface
      );
      const feeToken = new ethers.Contract(
        await getAddress("FeeToken", ChainId.LOCALHOST),
        Token.interface
      );

      const hre = require("hardhat");
      // Get before state
      console.log(
        `Deployer balance: ${ethers.utils.formatEther(
          await deployer.getBalance()
        )} ETH`
      );

      // Deploy Matching Engine
      const MatchingEngine = await ethers.getContractFactory("MatchingEngine");
      const matchingEngine = await MatchingEngine.deploy();
      await deployContract(matchingEngine, "MatchingEngine");

      // Deploy OrderbookFactory contract
      const OrderbookFactory = await ethers.getContractFactory(
        "OrderbookFactory"
      );
      const orderbookFactory = await OrderbookFactory.deploy();
      await deployContract(orderbookFactory, "OrderbookFactory");

      // Initialize OrderbookFactory args: [MatchingEngine.address]
      const initOrderbookFactory = await orderbookFactory.initialize(
        matchingEngine.address
      );
      await executeTx(initOrderbookFactory, "Initialize OrderbookFactory at");

      // Initialize MatchingEngine args: [OrderbookFactory.address, FeeToken.address, 30000]
      const initMatchingEngine = await matchingEngine.initialize(
        orderbookFactory.address,
        feeToken.address,
        30000
      );
      await executeTx(initMatchingEngine, "Initialize MatchingEngine at");

      // Trader1 approves matching engine of token1, token2
      const Token1ByTrader1 = await token1.connect(trader1);
      const Token2ByTrader1 = await token2.connect(trader1);
      const approveToken1ByTrader1 = await Token1ByTrader1.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken1ByTrader1,
        "Approve Matching Engine to use Token1 at"
      );
      const approveToken2ByTrader1 = await Token2ByTrader1.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken2ByTrader1,
        "Approve Matching Engine to use Token2 at"
      );

      // Trader2 approves matching engine of token1, token2
      const Token1ByTrader2 = await token1.connect(trader2);
      const Token2ByTrader2 = await token2.connect(trader2);
      const approveToken1ByTrader2 = await Token1ByTrader2.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken1ByTrader2,
        "Approve Matching Engine to use Token1 at"
      );
      const approveToken2ByTrader2 = await Token2ByTrader2.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken2ByTrader2,
        "Approve Matching Engine to use Token2 at"
      );

      // Booker approves matching engine of FeeToken
      const FeeTokenByBooker = await feeToken.connect(booker);
      const approveFeeTokenByBooker = await FeeTokenByBooker.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveFeeTokenByBooker,
        "Approve Matching Engine to use FeeToken at"
      );

      // Get after state
      console.log(
        `Deployer balance: ${ethers.utils.formatEther(
          await deployer.getBalance()
        )} ETH`
      );
    } else if (env === "testnet") {
      // Get WETH, deploy STND
      const Token = await ethers.getContractFactory("MockToken");
      console.log("start deploying token");
      const chainId: ChainId = await deployer.getChainId();

      const WETH = new ethers.Contract(WETH9_ADDRESS[chainId], Token.interface);

      const hre = require("hardhat");
      // Get before state
      console.log(
        `Deployer balance: ${ethers.utils.formatEther(
          await deployer.getBalance()
        )} ETH`
      );

      const token1 = await Token.deploy("Standard", "STND");
      await deployContract(token1, "Standard");

      // mint STND to deployer, trader1, trader2
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

      // Deploy Matching Engine
      const MatchingEngine = await ethers.getContractFactory("MatchingEngine");
      const matchingEngine = await MatchingEngine.deploy();
      await deployContract(matchingEngine, "MatchingEngine");

      // Deploy OrderbookFactory contract
      const OrderbookFactory = await ethers.getContractFactory(
        "OrderbookFactory"
      );
      const orderbookFactory = await OrderbookFactory.deploy();
      await deployContract(orderbookFactory, "OrderbookFactory");

      // Initialize OrderbookFactory args: [MatchingEngine.address]
      const initOrderbookFactory = await orderbookFactory.initialize(
        matchingEngine.address
      );
      await executeTx(initOrderbookFactory, "Initialize OrderbookFactory at");

      // Initialize MatchingEngine args: [OrderbookFactory.address, FeeToken.address, 30000]
      const initMatchingEngine = await matchingEngine.initialize(
        orderbookFactory.address,
        token1.address,
        300
      );
      await executeTx(initMatchingEngine, "Initialize MatchingEngine at");

      // Trader1 approves matching engine of token1, token2
      const Token1ByTrader1 = await token1.connect(trader1);
      const approveToken1ByTrader1 = await Token1ByTrader1.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken1ByTrader1,
        "Approve Matching Engine to use Token1 at"
      );

      // Trader2 approves matching engine of token1, token2
      const Token1ByTrader2 = await token1.connect(trader2);
      const approveToken1ByTrader2 = await Token1ByTrader2.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveToken1ByTrader2,
        "Approve Matching Engine to use Token1 at"
      );

      // Booker approves matching engine of FeeToken as STND
      const FeeTokenByBooker = await token1.connect(booker);
      const approveFeeTokenByBooker = await FeeTokenByBooker.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveFeeTokenByBooker,
        "Approve Matching Engine to use FeeToken at"
      );

      // Deployer approves matching engine of FeeToken as STND
      const FeeTokenByDeployer = await token1.connect(deployer);
      const approveFeeTokenByDeployer = await FeeTokenByDeployer.approve(
        matchingEngine.address,
        ethers.utils.parseEther("1000000")
      );
      await executeTx(
        approveFeeTokenByDeployer,
        "Approve Matching Engine to use FeeToken at"
      );

      // Add WETH, STND base/quote pair to MatchingEngine by deployer
      const addTokenPair = await matchingEngine.addPair(
        WETH.address,
        token1.address
      );
      await executeTx(addTokenPair, "Add token pair at");
    }
  });
