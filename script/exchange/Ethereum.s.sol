// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../contracts/safex/airdrops/TokenDispenser.sol";

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LINEA_TESTNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployMulticall3 is Deployer {
    function run() external {
        _setDeployer();
        new Multicall3();
        vm.stopBroadcast();
    }
}

contract DeployWETH is Deployer {
    function run() external {
        _setDeployer();
        vm.stopBroadcast();
    }
}

contract DeploySAFEXMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 12;
    address constant deployer_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    Treasury public treasury;
    
    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        treasury = new Treasury();
        matchingEngine.initialize(
            address(orderbookFactory), address(treasury), address(weth)
        );
        orderbookFactory.initialize(address(matchingEngine));
        vm.stopBroadcast();
    }
}

contract DeploySABTMainnetContracts is Deployer {
    Treasury constant treasury = Treasury(0xAF70BD3B32f70206a17DfdBe66529917E2Bf8c7B);
    uint32 constant spb = 12;
    address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // weth on mainnet
    address constant stablecoin = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // usdc on mainnet
    address constant matchingEngine = 0x93d744De3c805e15136459FEad77F17E5Ac6Cfcf;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;

    function run() external {
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(address(membership), address(matchingEngine), address(stablecoin), spb);
        treasury.set(address(membership), address(accountant), address(sabt));
        // Wire up matching engine with them
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(treasury)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));
    }
}

contract DeployTokenDispenser is Deployer {
    function run() external {
        _setDeployer();
        TokenDispenser dispenser = new TokenDispenser();
        vm.stopBroadcast();
    }
}

contract AddAirdrop is Deployer {
    address constant airdrop_token_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant dispenser_address =
        0xA8800c10F7276E2cfe025aAc849b812A2eC601fF;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    MockToken public airdropToken = MockToken(airdrop_token_address);
    TokenDispenser public dispenser = TokenDispenser(dispenser_address);
    uint256 public deposit_amount = 1e40;
    uint256 public airdrop_amount = 100000e18;

    function run() external {
        _setDeployer();
        airdropToken.mint(deployer_address, deposit_amount);
        airdropToken.transfer(dispenser_address, deposit_amount);
        dispenser.setTokenAmount(airdrop_token_address, airdrop_amount);
        vm.stopBroadcast();
    }
}

contract TestOrderbookSell is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getBookByPair(address(feeToken), address(stablecoin)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            100002e6,
            10000e18,
            true,
            1,
            0
        );
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(feeToken),
            address(stablecoin),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
        vm.stopBroadcast();
    }
}

contract TestGetPrices is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();

        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(feeToken),
            address(stablecoin),
            true,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(feeToken),
            address(stablecoin),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }

        vm.stopBroadcast();
    }
}
