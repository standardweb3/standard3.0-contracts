pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {MockBase} from "../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../utils/Utils.sol";
import {MatchingEngine} from "../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../contracts/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../contracts/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../contracts/mock/WETH9.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {NetworkState} from "../../contracts/safu/NetworkState.sol";

contract BaseSetup is Test {
    Utils public utils;
    MatchingEngine public matchingEngine;
    WETH9 public weth;
    OrderbookFactory public orderbookFactory;
    Orderbook public book;
    MockBase public token1;
    MockQuote public token2;
    MockBTC public btc;
    MockToken public feeToken;
    Treasury public treasury;
    NetworkState public networkState;
    address payable[] public users;
    address public trader1;
    address public trader2;
    address public booker;
    address public attacker;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(4);
        trader1 = users[0];
        vm.label(trader1, "Trader 1");
        trader2 = users[1];
        vm.label(trader2, "Trader 2");
        booker = users[2];
        vm.label(booker, "Booker");
        attacker = users[3];
        vm.label(attacker, "Attacker");
        token1 = new MockBase("Base", "BASE");
        token2 = new MockQuote("Quote", "QUOTE");
        btc = new MockBTC("Bitcoin", "BTC");
        weth = new WETH9();


        token1.mint(trader1, 10000000e18);
        token2.mint(trader1, 10000000e18);
        btc.mint(trader1, 10000000e18);
        token1.mint(trader2, 10000000e18);
        token2.mint(trader2, 10000000e18);
        btc.mint(trader2, 10000000e18);
        feeToken = new MockToken("Fee Token", "FEE");
        feeToken.mint(booker, 40000e18);
        matchingEngine = new MatchingEngine();
        orderbookFactory = new OrderbookFactory();
        orderbookFactory.initialize(address(matchingEngine));
        treasury = new Treasury();
        treasury.set(address(0), address(0), address(0));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(treasury),
            address(weth)
        );

        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10000000e18);
        vm.prank(trader1);
        token2.approve(address(matchingEngine), 10000000e18);
        vm.prank(trader1);
        btc.approve(address(matchingEngine), 10000000e18);
        vm.prank(trader2);
        token1.approve(address(matchingEngine), 10000000e18);
        vm.prank(trader2);
        token2.approve(address(matchingEngine), 10000e18);
        vm.prank(trader2);
        btc.approve(address(matchingEngine), 10000e8);

        // deploy network state
        networkState = new NetworkState();

    }
}

contract NetworkStateTest is BaseSetup {
    ErrToken public err;

    function testAddPair() public {
        // create orderbook
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.addPair(address(token2), address(token1));
    }

    function testAddPairWithOver18DecFails() public {
        // create orderbook
        super.setUp();

        err = new ErrToken("Error 1", "ERR1");
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(err));
        vm.expectRevert();
        matchingEngine.addPair(address(err), address(token2));
    }
}