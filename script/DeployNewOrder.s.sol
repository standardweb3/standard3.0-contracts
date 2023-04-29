// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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

contract Testnet is Script, Constants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Deploy fee Token for the matching engine
        MockToken feeToken = new MockToken("Standard", "STND");

        // Mint fee Token to the deployer, trader1, trader2
        feeToken.mint(ADDRESSES["deployer"], 1000000000000000000000000e18);
        feeToken.mint(ADDRESSES["trader1"], 100000e18);
        feeToken.mint(ADDRESSES["trader2"], 100000e18);

        // Deploy matching engine
        MatchingEngine matchingEngine = new MatchingEngine();
        OrderbookFactory orderbookFactory = new OrderbookFactory();
        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(feeToken),
            30000
        );

        // Deploy membership and SABT
        Membership membership = new Membership();
        SABT sabt = new SABT();

        // wire membership and SABT all together
        membership.initialize(address(sabt), ADDRESSES["deployer"]);
        sabt.initialize(address(membership), address(0));
        // set Fee in membership contract
        membership.setMembership(0, address(feeToken), 1000, 1000, 10000, 10);

        // Get membership
        membership.register(0);
        membership.subscribe(1, 10000000000000000);


        // Deploy stablecoin for accounting
        MockToken stablecoin = new MockToken("Stablecoin", "STBC");

        // Mint stablecoin to the deployer, trader1, trader2
        stablecoin.mint(ADDRESSES["deployer"], 100000e18);
        stablecoin.mint(ADDRESSES["trader1"], 100000e18);
        stablecoin.mint(ADDRESSES["trader2"], 100000e18);

        // Setup accountant and treasury
        BlockAccountant accountant = new BlockAccountant(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            1
        );
        Treasury treasury = new Treasury(address(accountant), address(sabt));

        // Wire up matching engine with them
        accountant.setTreasury(address(treasury));
        matchingEngine.setMembership(address(membership));
        matchingEngine.setAccountant(address(accountant));
        matchingEngine.setFeeTo(address(treasury));
        accountant.grantRole(accountant.REPORTER_ROLE(), address(matchingEngine));
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));

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
