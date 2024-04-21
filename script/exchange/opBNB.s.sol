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

contract DeployTestnetAssets is Deployer {
    function run() external {
        _setDeployer();
        MockToken feeToken = new MockToken("Standard", "STND");
        MockToken stablecoin = new MockToken("Stablecoin", "STBC");
        vm.stopBroadcast();
    }
}


contract DistributeTestnetAssets is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant deployer_address =
        0x34CCCa03631830cD8296c172bf3c31e126814ce9;
    address constant trader1_address =
        0x6408fb579e106fC59f964eC33FE123738A2D0Da3;
    address constant trader2_address =
        0xf5aE3B9dF4e6972a229E7915D55F9FBE5900fE95;
    address constant feeToken_address =
        0x0622C0b5F53FF7252A5F90b4031a9adaa67a2d02;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;

    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();
        // Mint fee Token to the deployer, trader1, trader2
        feeToken.mint(deployer_address, 1000000000000000000000000e18);
        feeToken.mint(trader1_address, 100000e18);
        feeToken.mint(trader2_address, 100000e18);

        // Mint stablecoin to the deployer, trader1, trader2
        stablecoin.mint(deployer_address, 1000000000000000000000000000e18);
        stablecoin.mint(trader1_address, 100000e18);
        stablecoin.mint(trader2_address, 100000e18);

        vm.stopBroadcast();
    }
}


contract TestOrderbookSell is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
    address constant feeToken_address =
        0xE57Cdf5796C2f5281EDF1B81129E1D4Ff9190815;
    address constant stablecoin_address =
        0xfB4c8b2658AB2bf32ab5Fc1627f115974B52FeA7;
    MatchingEngine public matchingEngine =
        MatchingEngine(payable(matching_engine_address));
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);
    Orderbook public book;

    function run() external {
        _setDeployer();

        

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            100002e6,
            10000e18,
            true,
            1,
            0,
            msg.sender
        );
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
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
        vm.stopBroadcast();
    }
}

contract TestGetPrices is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address =
        0xa7431faC42c7D5ff6C5EE297B9D65960B9970f12;
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
