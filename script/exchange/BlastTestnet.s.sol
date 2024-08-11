// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../src/mock/MockBTC.sol";
import {MockToken} from "../../src/mock/MockToken.sol";
import {MatchingEngine} from "../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../src/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../src/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../src/exchange/libraries/ExchangeOrderbook.sol";
import {TransferHelper} from "../../src/exchange/libraries/TransferHelper.sol";

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

contract DeployexchangeMainnetsrc is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 2;
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x4200000000000000000000000000000000000023;

    
    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        
        matchingEngine.initialize(
            address(orderbookFactory),
            0x34CCCa03631830cD8296c172bf3c31e126814ce9,
            address(weth)
        );
        
        orderbookFactory.initialize(address(matchingEngine));
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
        0x677B1CA9ACb800f7b40C89ef9BB441f79A7363f0;
    address constant base_addr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant quote_addr = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public base = MockToken(base_addr);
    MockToken public quote = MockToken(quote_addr);
    Orderbook public book;
    uint256 price = 100000e6;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 100000e18);
        quote.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(base),
            address(quote),
            price,
            10000e18,
            true,
            1,
            msg.sender
        );
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
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
        0x677B1CA9ACb800f7b40C89ef9BB441f79A7363f0;
    address constant base_addr = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant quote_addr = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public base = MockToken(base_addr);
    MockToken public quote = MockToken(quote_addr);
    Orderbook public book;
    uint256 price = 161498000000;

    function run() external {
        _setDeployer();

        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        base.approve(address(matchingEngine), 100000e18);

        TransferHelper.safeApprove(address(quote), address(matchingEngine), 10000000000);
        // add limit orders
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            price,
            1000000,
            true,
            5,
            msg.sender
        );
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
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
        0x677B1CA9ACb800f7b40C89ef9BB441f79A7363f0;
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

contract ShowOrderbook is Deployer {
    address constant token1 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant token2 = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    MatchingEngine matchingEngine =
        MatchingEngine(payable(0x677B1CA9ACb800f7b40C89ef9BB441f79A7363f0));

    function _showOrderbook(
        MatchingEngine matchingEngine,
        address base,
        address quote
    ) internal view {
        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(base, quote);
        console.log("Bid Head: ", bidHead);
        console.log("Ask Head: ", askHead);
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < askPrices.length; i++) {
            console.log("Ask price: ", askPrices[i]);
            ExchangeOrderbook.Order[] memory askOrders = matchingEngine
                .getOrders(
                    address(token1),
                    address(token2),
                    false,
                    askPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(askOrders[j].owner, askOrders[j].depositAmount);
            }
        }
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidPrices[i]);
        }
        console.log("Bid Orders: ");
        for (uint256 i = 0; i < bidPrices.length; i++) {
            console.log("Bid price: ", bidPrices[i]);
            ExchangeOrderbook.Order[] memory bidOrders = matchingEngine
                .getOrders(
                    address(token1),
                    address(token2),
                    true,
                    bidPrices[i],
                    10
                );
            for (uint256 j = 0; j < 10; j++) {
                console.log(bidOrders[j].owner, bidOrders[j].depositAmount);
            }
        }
    }

    function run() external {
        _setDeployer();
        _showOrderbook(matchingEngine, address(token1), address(token2));
        vm.stopBroadcast();
    }
}
