// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Multicall3} from "./Multicall3.sol";
import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract Multicall is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Multicall3 multicall3 = new Multicall3();
        vm.stopBroadcast();
    }
}
