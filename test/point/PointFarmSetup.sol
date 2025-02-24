pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Utils} from "../utils/Utils.sol";
import {MatchingEngine} from "../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../src/exchange/orderbooks/OrderbookFactory.sol";
import {MockToken} from "../../src/mock/MockToken.sol";
import {Orderbook} from "../../src/exchange/orderbooks/Orderbook.sol";
import {WETH9} from "../../src/mock/WETH9.sol";
import {PointFarm} from "../../src/point/PointFarm.sol";
import {Pass} from "../../src/point/Pass.sol";
import {STNDXP} from "../../src/point/STNDXP.sol";
import {PrizePool} from "../../src/point/PrizePool.sol";

import {MockBase} from "../../src/mock/MockBase.sol";
import {MockQuote} from "../../src/mock/MockQuote.sol";
import {MockUSDC} from "../../src/mock/MockUSDC.sol";

contract PointFarmSetup is Test {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    MockToken public stablecoin;
    MockToken public feeToken;
    MockBase public base;
    MockQuote public quote;
    MockUSDC public usdc;
    WETH9 public weth;
    address public foundation;
    address public reporter;
    OrderbookFactory orderbookFactory;

    Utils public utils;
    MatchingEngine public matchingEngine;
    address payable[] public users;
    address public trader1;
    address public trader2;
    address public booker;
    address public attacker;
    PointFarm public pointFarm;
    Pass public pass;
    STNDXP public point;
    PrizePool public prizePool;

    function setUp() public {
        utils = new Utils();
        users = utils.addUsers(6, users);
        trader1 = users[0];
        vm.label(trader1, "Trader 1");
        trader2 = users[1];
        vm.label(trader2, "Trader 2");
        booker = users[2];
        vm.label(booker, "Booker");
        attacker = users[3];
        vm.label(attacker, "Attacker");
        foundation = users[4];
        vm.label(foundation, "Foundation");
        reporter = users[5];
        vm.label(reporter, "Reporter");
        vm.startPrank(trader1);
        weth = new WETH9();
        feeToken = new MockToken("FeeToken", "FEE");
        stablecoin = new MockToken("Stablecoin", "STBC");
        matchingEngine = new MatchingEngine();
        orderbookFactory = new OrderbookFactory();
        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(address(orderbookFactory), address(booker), address(weth));

        base = new MockBase("Base Token", "BASE");
        usdc = new MockUSDC("Quote Token", "QUOTE");
        base.mint(trader1, type(uint256).max);
        usdc.mint(trader1, type(uint256).max);
        // make a price in matching engine where 1 base = 1 quote with buy and sell order
        matchingEngine.addPair(address(base), address(usdc), 341320000000, 0, address(base));
        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        matchingEngine.addPair(address(feeToken), address(stablecoin), 10000e8, 0, address(feeToken));

        point = new STNDXP();
        pointFarm = new PointFarm();
        prizePool = new PrizePool();
        pass = new Pass();
        pointFarm.initialize(
            address(pass), address(booker), address(weth), address(matchingEngine), address(point), address(stablecoin)
        );
        pass.initialize(address(pointFarm));
        matchingEngine.setFeeTo(address(pointFarm));
        point.grantRole(MINTER_ROLE, address(pointFarm));
        point.grantRole(BURNER_ROLE, address(prizePool));
        stablecoin.mint(address(prizePool), 10e30);
        prizePool.initialize(address(stablecoin), address(point));

        feeToken.mint(trader1, 100000000e18);
        feeToken.mint(trader2, 10000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);
        vm.stopPrank();
        // set stablecoin price
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 100000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngine), 10000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader2);
        feeToken.approve(address(matchingEngine), 10000e18);
        // mine 1000 blocks
        utils.mineBlocks(1000);
        vm.prank(trader2);
        matchingEngine.limitSell(address(feeToken), address(stablecoin), 10000e8, 1000e10, true, 1, trader2);
        // match the order to make lmp so that accountant can report
        vm.prank(trader1);
        feeToken.approve(address(matchingEngine), 10000e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 10000e8, 1000e10, true, 1, trader1);
    }
}
