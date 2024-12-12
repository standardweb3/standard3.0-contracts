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
    address impl = 0xE0892785D00F192110A05282387fBAC21b942Aad;
    address admin = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address orderbookFactory = 0xf297cd3077dEC0f07A814999b7B282A8EA911cC0;
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
    address constant impl = 0xE0892785D00F192110A05282387fBAC21b942Aad;
    address constant proxy_addr = 0x01c2dfc35CBd8d759E968d39B56f1628F23Eaad9;

    uint32 constant spb = 2;
    address constant deployer_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant foundation_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant orderbookFactory =
        0xf297cd3077dEC0f07A814999b7B282A8EA911cC0;

    function run() external {
        _setDeployer();
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
    address constant weth = 0xA51894664A773981C6C112C43ce576f315d5b1B6;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(deployer_address),
            address(weth)
        );

        vm.stopBroadcast();
    }
}

contract DeployPointFarmMainnetContracts is Deployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address =
        0xE0892785D00F192110A05282387fBAC21b942Aad;
    address constant foundation_address =
        0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
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
            payable(address(0xE0892785D00F192110A05282387fBAC21b942Aad))
        );
    address constant base = 0x4200000000000000000000000000000000000006;
    address constant quote = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant initMarketPrice = 341320000000;

    function run() external {
        _setDeployer();
        matchingEngine.addPair(base, quote, initMarketPrice, 0, base);
        vm.stopBroadcast();
    }
}

contract CreateEventMainnet is Deployer {
    PointFarm public pointFarm;
    address constant pointFarm_address =
        0x90Fcc35562f3E4A0bDf1dAd6B6eB0c1F13d0d62c;
    // Unix Epoch time for start/end
    uint256 startDate = 0;
    uint256 endDate = 0;

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
        0x90Fcc35562f3E4A0bDf1dAd6B6eB0c1F13d0d62c;
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
