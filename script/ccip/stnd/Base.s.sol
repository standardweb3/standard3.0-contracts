// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../../../src/mock/MockBTC.sol";
import {MockToken} from "../../../src/mock/MockToken.sol";
import {MatchingEngine} from "../../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../src/exchange/orderbooks/Orderbook.sol";
import {Multicall3} from "../../Multicall3.sol";
import {TokenDispenser} from "../../../src/exchange/airdrops/TokenDispenser.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {Standard} from "../../../src/stnd/ccip/STND.sol";

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

contract DeployStandard is Deployer {
    Standard public stnd;
    function run() external {
        _setDeployer();
        stnd = new Standard();
        vm.stopBroadcast();
    }
}

contract GrantMinterRole is Deployer {
    address stnd_address = 0x7a2e3a7A1bf8FaCCAd68115DC509DB5a5af4e7e4;
    Standard public stnd;
    address minter = address(0);
    function run() external {
        _setDeployer();
        stnd = Standard(stnd_address);
        stnd.grantRole(stnd.MINTER_ROLE(), minter);
    }
}