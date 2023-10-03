pragma solidity >=0.8;

import {BaseSetup} from "./Orderbook.t.sol";

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";
import {WETH9} from "../../contracts/mock/WETH9.sol";
import {Revenue} from "../../contracts/sabt/Revenue.sol";

contract SAFEXFeeTierSetup is BaseSetup {
    OrderbookFactory public orderbookFactoryFeeTier;
    MatchingEngine public matchingEngineFeeTier;
    Membership public membership;
    Treasury public treasury;
    BlockAccountant public accountant;
    SABT public sabt;
    MockToken public stablecoin;
    address public foundation;
    address public reporter;

    function feeTierSetUp() public {
        users = utils.addUsers(2, users);
        foundation = users[4];
        reporter = users[5];

        stablecoin = new MockToken("Stablecoin", "STBC");
        membership = new Membership();
        sabt = new SABT();

        orderbookFactoryFeeTier = new OrderbookFactory();
        matchingEngineFeeTier = new MatchingEngine();

        accountant = new BlockAccountant();
        accountant.initialize(address(membership), address(matchingEngineFeeTier), address(stablecoin), 1);
        treasury = new Treasury();
        treasury.initialize(address(accountant), address(sabt));
        orderbookFactoryFeeTier.initialize(address(matchingEngineFeeTier));
        revenue = new Revenue();
        revenue.set(address(membership), address(accountant), address(treasury));
        matchingEngineFeeTier.initialize(
            address(orderbookFactoryFeeTier), address(revenue), address(weth)
        );
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(revenue)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(revenue));

        feeToken.mint(trader1, 10e41);
        feeToken.mint(trader2, 100000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        stablecoin.approve(address(membership), 10000e18);

        // initialize  membership contract
        membership.initialize(address(sabt), foundation, address(weth));
        // initialize SABT
        sabt.initialize(address(membership));
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000);

        // set stablecoin price
        vm.prank(booker);
        feeToken.approve(address(matchingEngineFeeTier), 100000e18);
        vm.prank(booker);
        matchingEngineFeeTier.addPair(address(feeToken), address(stablecoin));
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngineFeeTier), 10000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader2);
        feeToken.approve(address(matchingEngineFeeTier), 10000e18);

        // register trader1 into membership
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        membership.register(1, address(feeToken));
        assert(sabt.balanceOf(trader1, 1) == 1);

        // subscribe
        vm.prank(trader1);
        feeToken.approve(address(membership), 1e40);
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));

        // mine 1000 blocks
        utils.mineBlocks(1000);
        console.log("Block number after mining 1000 blocks: ", block.number);
        console.log("Financial block where accountant started its accounting: ", accountant.fb());

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        vm.prank(trader2);
        matchingEngineFeeTier.limitSell(address(feeToken), address(stablecoin), 1000e8, 10000e18, true, 1, 0);
        // match the order to make lmp so that accountant can report
        stablecoin.mint(address(trader1), 1000000000e18);
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngineFeeTier), 1000000000e18);
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100000e18, true, 5, 1);
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(address(feeToken), address(stablecoin), 1000e8, 10000000e18, true, 5, 1);
    }
}

contract FeeTierTest is SAFEXFeeTierSetup {
    // After trading, TI and trader level can be shown
    function testTraderProfileShowsTIandLvl() public {
        super.feeTierSetUp();
        uint256 point = accountant.pointOf(1, 0);
        uint256 ti = accountant.getTI(1);
        console.log("Trader 1 Trader Point:");
        console.log(point);
        console.log("Trader 1 TI(%):");
        console.log(ti);
    }

    // Traders with premium accounts shows assigned level regardless of trading performance
    function testTraderProfileShowsAssignedLvl() public {
        super.feeTierSetUp();
        uint256 level = accountant.levelOf(1);
        console.log("Trader 1 level:");
        console.log(level);
    }
}