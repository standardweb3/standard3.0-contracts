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
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

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

contract DeployExchangeProxy is Deployer {
    address impl = 0x925826804eC6e3448edB064A832663514E3DB19E;
    address admin = 0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address orderbookFactory = 0xeE78a95F7b687c0B5202A2b61bD4b6CcBee5D6aa;
    address weth = 0x4200000000000000000000000000000000000006;
   

    function run() external {
        _setDeployer();
        bytes memory data = "";
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            impl,
            admin,
            data
        );
        MatchingEngine matchingEngine = MatchingEngine(payable(address(proxy)));
        matchingEngine.initialize(
            orderbookFactory,
            admin,
            weth
        );
        vm.stopBroadcast();
    }
}

contract InitializeExchangeProxy is Deployer {
    address constant impl = 0x925826804eC6e3448edB064A832663514E3DB19E;
    address constant proxy_addr = 0x925826804eC6e3448edB064A832663514E3DB19E;

    uint32 constant spb = 2;
    address constant deployer_address =
        0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address constant foundation_address =
        0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant orderbookFactory =
        0xeE78a95F7b687c0B5202A2b61bD4b6CcBee5D6aa;

    function run() external {
        _setDeployer();
    }
}

contract DeployExchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    uint32 constant spb = 2;
    address constant deployer_address =
        0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address constant foundation_address =
        0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address constant weth = 0x4200000000000000000000000000000000000006;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        matchingEngine.initialize(
            address(orderbookFactory),
            address(0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503),
            address(weth)
        );

        orderbookFactory.initialize(address(matchingEngine));

        vm.stopBroadcast();
    }
}

contract DeployPointFarmMainnetContracts is Deployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address =
        0x925826804eC6e3448edB064A832663514E3DB19E;
    address constant foundation_address =
        0xd64a0cB64B6b1DaEF59259862a936D1B1B2e0503;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant stablecoin_address =
        0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
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
        matchingEngine = MatchingEngine(
            payable(address(matchingEngine_address))
        );
        matchingEngine.setFeeTo(address(pointFarm));
        point.grantRole(MINTER_ROLE, address(pointFarm));
        vm.stopBroadcast();
    }
}

contract CreatePairMainnet is Deployer {
    MatchingEngine public matchingEngine =
        MatchingEngine(
            payable(address(0x925826804eC6e3448edB064A832663514E3DB19E))
        );
    address constant base = 0x4200000000000000000000000000000000000006;
    address constant quote = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant initMarketPrice = 341320000000;

    function run() external {
        _setDeployer();
        matchingEngine.addPair(base, quote, initMarketPrice);
        vm.stopBroadcast();
    }
}

contract CreateEventMainnet is Deployer {
    PointFarm public pointFarm;
    address constant STNDXP = 0x2409e7fB962acd0227A60dF35DC92db39482a91E;
    address constant pointFarm_address =
        0x6b2FCA13c5C9edFf97a035432D82A94D4A20bC47;
    // Unix Epoch time for start/end
    uint256 startDate = 1719090093;
    uint256 endDate = 1721719836;

    function run() external {
        _setDeployer();
        pointFarm = PointFarm(pointFarm_address);
        startDate = startDate == 0 ? block.timestamp : startDate;
        endDate = endDate == 0 ? block.timestamp + 30 days : endDate;
        pointFarm.createEvent(startDate, endDate);
        vm.stopBroadcast();
    }
}

contract SetEventMainnet is Deployer {
    PointFarm public pointFarm;
    address constant pointFarm_address =
        0x6b2FCA13c5C9edFf97a035432D82A94D4A20bC47;
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
        TransferHelper.safeTransfer(
            stablecoin_address,
            address(prizePool),
            prize_amount
        );
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
