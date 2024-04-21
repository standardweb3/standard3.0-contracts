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
import {ERC20MintablePausableBurnable} from "../../contracts/stnd/ccip/STND.sol";

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

contract DeploySTND is Deployer {
    ERC20MintablePausableBurnable public stnd;
    function run() external {
        _setDeployer();
        stnd = new ERC20MintablePausableBurnable("Standard (CCIP)", "STND");
        vm.stopBroadcast();
    }
}

contract GrantMinterRole is Deployer {
    address stnd_address = 0xAd117e349e05c7B718B9AfbFde88EA60376bCE14;
    ERC20MintablePausableBurnable public stnd;
    address minter = address(0);
    function run() external {
        _setDeployer();
        stnd = ERC20MintablePausableBurnable(stnd_address);
        stnd.grantRole(stnd.MINTER_ROLE(), minter);
    }
}