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
import {STNDXP} from "../../src/point/STNDXP.sol";
import {PointFarm} from "../../src/point/PointFarm.sol";
import {Pass} from "../../src/point/Pass.sol";
import {PrizePool} from "../../src/point/PrizePool.sol";

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

contract DeployExchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 2;
    address constant deployer_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant foundation_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x4200000000000000000000000000000000000001;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        matchingEngine.initialize(
            address(orderbookFactory),
            address(deployer_address),
            address(weth)
        );

        orderbookFactory.initialize(address(matchingEngine));

        vm.stopBroadcast();
    }
}

contract SetupPointMainnet is Deployer{

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address = 0x41f21E381a70E404854D1f95788208BBc6A8Cd72;
    address constant foundation_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x4200000000000000000000000000000000000001;
    address constant stablecoin_address = address(0);
    STNDXP public point;
    Pass public pass;
    PointFarm public pointFarm;

    function run() external {
        _setDeployer();
        point = new STNDXP();
        pointFarm = new PointFarm();
        pass = new Pass();
        pointFarm.initialize(
            address(pass),
            address(foundation_address),
            address(weth),
            address(matchingEngine),
            address(point),
            address(stablecoin_address)
        );
        pass.initialize(address(pointFarm));
        matchingEngine = MatchingEngine(payable(address(matchingEngine_address)));
        matchingEngine.setFeeTo(address(pointFarm));
        point.grantRole(MINTER_ROLE, address(pointFarm));
        vm.stopBroadcast();
    }
}

contract CreatePairMainnet is Deployer {
    MatchingEngine public matchingEngine =
        MatchingEngine(
            payable(address(0x41f21E381a70E404854D1f95788208BBc6A8Cd72))
        );
    address constant base = 0x0Cf7c2A584988871b654Bd79f96899e4cd6C41C0;
    address constant quote = 0x0257e4d92C00C9EfcCa1d641b224d7d09cfa4522;
    uint256 constant initMarketPrice = 100000000;

    function run() external {
        _setDeployer();
        matchingEngine.addPair(base, quote, initMarketPrice, 0);
        vm.stopBroadcast();
    }
}

contract CreateEventMainnet is Deployer {
    PointFarm public pointFarm;
    address constant pointFarm_address = address(0);
    // timestamp in seconds
    uint256 startDate = 0;
    uint256 endDate = 0;

    function run() external {
        _setDeployer();
        pointFarm = PointFarm(pointFarm_address);
        pointFarm.createEvent(startDate, endDate);
        vm.stopBroadcast();
    }
}

contract SetEventMainnet is Deployer {
    PointFarm public pointFarm;
    address constant pointFarm_address = address(0);
    // timestamp in seconds
    uint256 endDate = 0;

    function run() external {
        _setDeployer();
        pointFarm = PointFarm(pointFarm_address);
        pointFarm.setEvent(endDate);
        vm.stopBroadcast();
    }
}

contract SetupPrizePoolMainnet is Deployer {
    PrizePool public prizePool;
    STNDXP public point;
    address constant point_address = address(0);
    address constant stablecoin_address = address(0);
    uint256 constant prize_amount = 0;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function run() external {
        _setDeployer();
        prizePool = new PrizePool();
        point = STNDXP(point_address);
        point.grantRole(BURNER_ROLE, address(prizePool));
        TransferHelper.safeTransfer(stablecoin_address, address(prizePool), prize_amount);
        prizePool.initialize(address(stablecoin_address), address(point));
        vm.stopBroadcast();
    }
}

contract collectFee is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    PointFarm public pointFarm;
    address constant pointFarm_address = address(0);
    address constant token_address = address(0);



    function run() external {
        pointFarm = PointFarm(pointFarm_address);
        pointFarm.collectFee(token_address);
    }
}

contract SetSpread is Deployer {
    MatchingEngine public matchingEngine;
    address public base;
    address public quote;
    function run() external {
        _setDeployer();
        console.log("Setitng spread...");
        address matchingEngineAddress = 0x41f21E381a70E404854D1f95788208BBc6A8Cd72;
        matchingEngine = MatchingEngine(payable(matchingEngineAddress));
        base = 0x61e0D34b5206Fa8005EC1De8000df9B9dDee23Db;
        quote = 0x4200000000000000000000000000000000000001;
        matchingEngine.setSpread(base, quote, 10, 10);
        vm.stopBroadcast();
    }
}

contract ShowOrderbook is Deployer {
    address constant matching_engine_address =
        0x41f21E381a70E404854D1f95788208BBc6A8Cd72;
    address constant base_address = 0x4200000000000000000000000000000000000001;
    address constant quote_address = 0x0Cf7c2A584988871b654Bd79f96899e4cd6C41C0; 
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