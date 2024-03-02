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
import {MatchingEngine} from "../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../contracts/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../contracts/exchange/libraries/ExchangeOrderbook.sol";

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

contract DeployexchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 12;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;

    Treasury public treasury;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        //treasury = new Treasury();
        matchingEngine.initialize(
            address(orderbookFactory),
            address(0x7a2e3a7A1bf8FaCCAd68115DC509DB5a5af4e7e4),
            address(weth)
        );
        orderbookFactory.initialize(address(matchingEngine));
        vm.stopBroadcast();
    }
}

contract DeploySABTMainnetContracts is Deployer {
    Treasury constant treasury =
        Treasury(0x7a2e3a7A1bf8FaCCAd68115DC509DB5a5af4e7e4);
    uint32 constant spb = 12;
    address constant weth = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // weth on mainnet
    address constant stablecoin = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; // usdc on mainnet
    address constant matchingEngine =
        0xa2F02d36206EDD2EAE9Fd5FBaBd90CdFCE939614;
    address constant orderbookFactory =
        0x73EbE91068d0908cbF51f83B5c7b58824f3Ae69B;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;

    function run() external {
        Membership membership = new Membership();
        SABT sabt = new SABT();
        membership.initialize(address(sabt), foundation_address, weth);
        sabt.initialize(address(membership));
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant();
        accountant.initialize(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            spb
        );
        treasury.set(address(membership), address(accountant), address(sabt));
        // Wire up matching engine with them
        accountant.grantRole(accountant.REPORTER_ROLE(), address(treasury));
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

contract TestAddPair is Deployer {
    address constant matching_engine_address =
        0x99e87D3f46079CeeE33859Fb6055A912090c9683;
    address constant base_address = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
    address constant quote_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;

    function run() external {
        _setDeployer();

        MatchingEngine matchingEngine = MatchingEngine(
            payable(matching_engine_address)
        );
        matchingEngine.addPair(address(base_address), address(quote_address));
    }
}

contract TestOrderbookSell is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0x66a8b38D8B573Dbb6beBe163324b2DC0070d3430;
    address constant base_address = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
    address constant quote_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public base = MockToken(base_address);
    MockToken public quote = MockToken(quote_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 1e18);
        quote.approve(address(matchingEngine), 1e18);

        matchingEngine.mktPrice(address(base), address(quote));
        // add limit orders
        matchingEngine.limitSell(
            address(base),
            address(quote),
            50600,
            100000,
            true,
            1,
            0,
            msg.sender
        );
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
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

contract TestOrderbookBuy is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa2F02d36206EDD2EAE9Fd5FBaBd90CdFCE939614;
    address constant quote_address = 0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376;
    address constant base_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;

    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public base = MockToken(base_address);
    MockToken public quote = MockToken(quote_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 100000e18);
        quote.approve(address(matchingEngine), 100000000e18);

        matchingEngine.mktPrice(address(base), address(quote));
        // add limit orders
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            2234e8,
            100000,
            true,
            1,
            0,
            msg.sender
        );
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
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
        0x99e87D3f46079CeeE33859Fb6055A912090c9683;
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
        //matchingEngine.getOrders(address(base), address(quote), true, 0, 0);
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

contract ShowOrderbook is Deployer {
    address constant matching_engine_address =
        0xa2F02d36206EDD2EAE9Fd5FBaBd90CdFCE939614;
    address constant base_address = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address constant quote_address = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; 
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));

    function _orderbookIsEmpty(address b_addr, address q_addr, uint256 price, bool isBid) internal view returns (bool) {
        address orderbook = matchingEngine.getPair(b_addr, q_addr);
        console.log("Orderbook", orderbook);
        return Orderbook(payable(orderbook)).isEmpty(isBid, price);
    }

    function _showOrderbook(
        MatchingEngine matchingEngine,
        address base,
        address quote
    ) internal view {
        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(base, quote);
        console.log("Bid Head: ", bidHead);
        console.log("Ask Head: ", askHead);
        console.log("is empty: ", _orderbookIsEmpty(base, quote, askHead, false));
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            true,
            20
        );
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(base),
            address(quote),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log(askPrices[i]);
            console.log("Ask Orders: ");
            uint32[] memory askOrderIds = matchingEngine.getOrderIds(
                address(base),
                address(quote),
                false,
                askPrices[i],
                10
            );
            ExchangeOrderbook.Order[] memory askOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    false,
                    askPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(askOrderIds[j], askOrders[j].owner, askOrders[j].depositAmount);
            }
        }

        console.log("Bid prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log(bidPrices[i]);
            console.log("Bid Orders: ");
            uint32[] memory bidOrderIds = matchingEngine.getOrderIds(
                address(base),
                address(quote),
                false,
                bidPrices[i],
                10
            );
            ExchangeOrderbook.Order[] memory bidOrders = matchingEngine
                .getOrders(
                    address(base),
                    address(quote),
                    true,
                    bidPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(bidOrderIds[j], bidOrders[j].owner, bidOrders[j].depositAmount);
            }
        }
    }

    function run() external {
        _setDeployer();
        _showOrderbook(
            MatchingEngine(payable(matching_engine_address)),
            base_address,
            quote_address
        );
        vm.stopBroadcast();
    }
}
