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
import {WETH9} from "../../src/mock/WETH9.sol";

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
        new WETH9();
        vm.stopBroadcast();
    }
}

contract DeployMockToken is Deployer {
    function run() external {
        _setDeployer();
        new MockToken("CZ AI", "CZAI", 18);
        vm.stopBroadcast();
    }
}

contract DeployExchangeProxy is Deployer {
    address impl = 0xE0892785D00F192110A05282387fBAC21b942Aad;
    address admin = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address orderbookFactory = 0xd7ABA1cbAd246249be6a0de9a449FB5EDEFf1E47;
    address weth = 0x4200000000000000000000000000000000000006;

    function run() external {
        _setDeployer();
        bytes memory data = "";
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(impl, admin, data);
        MatchingEngine matchingEngine = MatchingEngine(payable(address(proxy)));
        matchingEngine.initialize(orderbookFactory, admin, weth);
        vm.stopBroadcast();
    }
}

contract InitializeExchangeProxy is Deployer {
    address constant impl = 0xE0892785D00F192110A05282387fBAC21b942Aad;
    address constant proxy_addr = 0x01c2dfc35CBd8d759E968d39B56f1628F23Eaad9;

    uint32 constant spb = 2;
    address constant deployer_address = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant foundation_address = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x4200000000000000000000000000000000000006;
    address constant orderbookFactory = 0xd7ABA1cbAd246249be6a0de9a449FB5EDEFf1E47;

    function run() external {
        _setDeployer();
    }
}

contract DeployExchangeMainnetContracts is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    /// Second per block to finalize
    address constant deployer_address = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant foundation_address = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0x008fCD6315c68EbAa31244aea174993f63Ef14D5;

    function run() external {
        _setDeployer();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();

        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(address(orderbookFactory), address(deployer_address), address(weth));

        vm.stopBroadcast();
    }
}

contract DeployPointFarmMainnetContracts is Deployer {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address = 0x6B5A13Ca93871187330aE6d9E34cdAD610aA54cd;
    address constant foundation_address = 0xF8FB4672170607C95663f4Cc674dDb1386b7CfE0;
    address constant weth = 0xe8CabF9d1FFB6CE23cF0a86641849543ec7BD7d5;
    address constant stablecoin_address = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
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
    MatchingEngine public matchingEngine = MatchingEngine(payable(address(0x615a19aDE5C452DCb0DA995989bf74Ca86092c76)));
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
    address constant pointFarm_address = 0x90Fcc35562f3E4A0bDf1dAd6B6eB0c1F13d0d62c;
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
    address constant pointFarm_address = 0x90Fcc35562f3E4A0bDf1dAd6B6eB0c1F13d0d62c;
    // timestamp in seconds
    uint256 endDate = 0;

    function run() external {
        _setDeployer();
        pointFarm = PointFarm(pointFarm_address);
        pointFarm.setEvent(endDate);
        vm.stopBroadcast();
    }
}

contract AddPair is Deployer {
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address = 0x6B5A13Ca93871187330aE6d9E34cdAD610aA54cd;
    address constant base = 0xBAb93B7ad7fE8692A878B95a8e689423437cc500;
    address constant quote = 0xa111a06BDEbb8b1dAA79000F4B386A36E0AccE56;
    uint256 constant price = 147777000000;

    function run() external {
        _setDeployer();
        matchingEngine = MatchingEngine(payable(address(matchingEngine_address)));
        matchingEngine.addPair(base, quote, price, 0, base);
        vm.stopBroadcast();
    }
}

contract SetupPriceOnPair is Deployer {
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address = 0x6B5A13Ca93871187330aE6d9E34cdAD610aA54cd;
    address constant base = 0xa111a06BDEbb8b1dAA79000F4B386A36E0AccE56;
    address constant quote = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    uint256 constant price = 250000000;

    function run() external {
        _setDeployer();
        matchingEngine = MatchingEngine(payable(address(matchingEngine_address)));
        matchingEngine.addPair(base, quote, price, 0, base);
        vm.stopBroadcast();
    }
}

contract SetupSpreadOnPair is Deployer {
    MatchingEngine public matchingEngine;
    address constant matchingEngine_address = 0x6B5A13Ca93871187330aE6d9E34cdAD610aA54cd;
    address constant base = 0xa111a06BDEbb8b1dAA79000F4B386A36E0AccE56;
    address constant quote = 0xF1815bd50389c46847f0Bda824eC8da914045D14;
    uint32 constant buyTick = 1000000;
    uint32 constant sellTick = 100000;
    /*
     "buy_tick": 1000000,
    "sell_tick": 100000
    */

    function run() external {
        _setDeployer();
        matchingEngine = MatchingEngine(payable(address(matchingEngine_address)));
        matchingEngine.setSpread(base, quote, buyTick, sellTick);
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
    address constant deployer_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant foundation_address = 0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    PointFarm public pointFarm;
    address constant pointFarm_address = address(0);
    address constant token_address = address(0);

    function run() external {
        pointFarm = PointFarm(pointFarm_address);
        pointFarm.collectFee(token_address);
    }
}
