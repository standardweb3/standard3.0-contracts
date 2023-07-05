// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MockBTC} from "../contracts/mock/MockBTC.sol";
import {SABT} from "../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../contracts/sabt/Membership.sol";
import {Treasury} from "../contracts/sabt/Treasury.sol";
import {MockToken} from "../contracts/mock/MockToken.sol";
import {Constants} from "./Constants.sol";
import {MatchingEngine} from "../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Multicall3} from "./Multicall3.sol";

contract Deployer is Script {
    function _setDeployer() internal {
        uint256 deployerPrivateKey = vm.envUint(
            "LINEA_TESTNET_DEPLOYER_PRIVATE_KEY"
        );
        vm.startBroadcast(deployerPrivateKey);
    }
}

contract DeployMulticall3 is Deployer {
    function run() external {
        _setDeployer();
        Multicall3 multicall3 = new Multicall3();
        vm.stopBroadcast();
    }
}

contract DeployWETH is Deployer {
    function run() external {
        _setDeployer();
        vm.stopBroadcast();
    }
}

contract DeployTestnetAssetsAndContracts is Deployer {
    function run() external {
        _setDeployer();
        MockToken feeToken = new MockToken("Standard", "STND");
        MockToken stablecoin = new MockToken("Stablecoin", "STBC");
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        MatchingEngine matchingEngine = new MatchingEngine();
        Membership membership = new Membership();
        SABT sabt = new SABT();
        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            1
        );
        Treasury treasury = new Treasury(address(accountant), address(sabt));
        vm.stopBroadcast();
    }
}

contract WireSABTModule is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address = 0x0;
    address constant membership_address = 0x0;
    address constant sabt_address = 0x0;
    address constant stablecoin_address = 0x0;
    address constant block_accountant_address = 0x0;
    address constant treasury_address = 0x0;

    Membership public membership = Membership(membership_address);
    SABT public sabt = SABT(sabt_address);
    MockToken public stablecoin = MockToken(stablecoin_address);
    BlockAccountant public accountant =
        BlockAccountant(block_accountant_address);
    Treasury public treasury = Treasury(treasury_address);

    function run() external {
        _setDeployer();
        // Deploy contracts
        // wire membership and SABT all together
        membership.initialize(sabt_address, ADDRESSES["deployer"]);
        sabt.initialize(address(membership), address(0));
        // set Fee in membership contract
        membership.setMembership(0, address(feeToken), 1000, 1000, 10000);

        // Get membership
        membership.register(0, address(feeToken));
        membership.subscribe(1, 10000000000000000, address(feeToken));

        // Wire up matching engine with them
        accountant.setTreasury(address(treasury));
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(matchingEngine)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));

        vm.stopBroadcast();
    }
}

contract WireSAFEXModule is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address = 0x0;
    address constant orderbookFactory_address = 0x0;
    address constant membership_address = 0x0;
    address constant accountant_address = 0x0;
    address constant treasury_address = 0x0;
    MatchingEngine public matchingEngine =
        MatchingEngine(matching_engine_address);

    function run() external {
        _setDeployer();
        matchingEngine.initialize(
            address(feeToken),
            30000,
            address(orderbookFactory),
            membership_address,
            accountant_address,
            treasury_address
        );
        vm.stopBroadcast();
    }
}

contract DistributeTestnetAssets is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address = 0x0;
    address constant membership_address = 0x0;
    address constant deployer_address = 0x0;
    address constant trader1_address = 0x0;
    address constant trader2_address = 0x0;

    function run() external {
        _setDeployer();
        // Mint fee Token to the deployer, trader1, trader2
        feeToken.mint(deployer_address, 1000000000000000000000000e18);
        feeToken.mint(trader1_address, 100000e18);
        feeToken.mint(trader2_address, 100000e18);

        // Mint stablecoin to the deployer, trader1, trader2
        stablecoin.mint(deployer_address, 100000e18);
        stablecoin.mint(trader1_address, 100000e18);
        stablecoin.mint(trader2_address, 100000e18);

        vm.stopBroadcast();
    }
}

contract SetupSAFEXInitialParameters is Deployer {
    // Change address constants on deploying to other networks from DeployAssets
    address constant matching_engine_address = 0x0;
    address constant feeToken_address = 0x0;
    address constant stablecoin_address = 0x0;
    MatchingEngine public matchingEngine =
        MatchingEngine(matching_engine_address);
    MockToken public feeToken = MockToken(feeToken_address);
    MockToken public stablecoin = MockToken(stablecoin_address);

    function run() external {
        _setDeployer();
        // Setup pair between stablecoin and feeToken with price
        feeToken.approve(address(matchingEngine), 100000e18);
        matchingEngine.addPair(address(feeToken), address(stablecoin));

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        feeToken.approve(address(matchingEngine), 100000e18);
        stablecoin.approve(address(matchingEngine), 100000e18);
        // add limit orders
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            10000e18,
            1000e8,
            true,
            1,
            0
        );
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            10000e18,
            1000e8,
            false,
            1,
            1
        );
        vm.stopBroadcast();
    }
}
