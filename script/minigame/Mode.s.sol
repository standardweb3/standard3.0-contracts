// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../src/mock/MockBTC.sol";
import {MockToken} from "../../src/mock/MockToken.sol";
//import {MatchingEngine} from "../../src/exchange/MatchingEngine.sol";
import {MatchingEngineMode} from "../../src/exchange/MatchingEngineMode.sol";
import {OrderbookFactory} from "../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../src/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../Multicall3.sol";
import {TokenDispenser} from "../../src/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../src/exchange/libraries/ExchangeOrderbook.sol";
import {BrawlPortal} from "../../src/minigame/BrawlPortal.sol";
import {TimeBrawlFactory} from "../../src/minigame/brawls/time/TimeBrawlFactory.sol";

interface IWETHMinimal {
    function WETH() external view returns (address);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint("LINEA_TESTNET_DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployMulticall3 is Deployer {
    address multicall3 = 0x2CC505C4bc86B28503B5b8C450407D32e5E20A9f;
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

contract DeployMinigame is Deployer {
    address matching_engine_address = 0x3df48559F01F07691D03179380919767553a74f8;
    function run() external {
        _setDeployer();
        BrawlPortal portal = new BrawlPortal();
        TimeBrawlFactory factory = new TimeBrawlFactory();
        portal.initialize(matching_engine_address, address(factory));
        factory.initialize(address(portal));
    }
}