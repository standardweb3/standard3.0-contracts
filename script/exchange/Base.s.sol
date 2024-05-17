// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {MatchingEngine} from "../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../contracts/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../contracts/exchange/libraries/ExchangeOrderbook.sol";
import {TransferHelper} from "../../contracts/exchange/libraries/TransferHelper.sol";
import {STXP} from "../../contracts/point/STXP.sol";
import {PointFarm} from "../../contracts/point/PointFarm.sol";
import {Pass} from "../../contracts/point/Pass.sol";
import {PrizePool} from "../../contracts/point/PrizePool.sol";

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
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x4200000000000000000000000000000000000006;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        
        matchingEngine.initialize(
            address(orderbookFactory),
            address(0x34CCCa03631830cD8296c172bf3c31e126814ce9),
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
    address constant matchingEngine_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant stablecoin_address = address(0);
    STXP public point;
    Pass public pass;
    PointFarm public pointFarm;

    function run() external {
        _setDeployer();
        point = new STXP();
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
    STXP public point;
    address constant point_address = address(0);
    address constant stablecoin_address = address(0);
    uint256 constant prize_amount = 0;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    function run() external {
        _setDeployer();
        prizePool = new PrizePool();
        point = STXP(point_address);
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

