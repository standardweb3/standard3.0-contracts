pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MockToken} from "../../src/mock/MockToken.sol";
import {MockBase} from "../../src/mock/MockBase.sol";
import {MockQuote} from "../../src/mock/MockQuote.sol";
import {MockBTC} from "../../src/mock/MockBTC.sol";
import {ErrToken} from "../../src/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../utils/Utils.sol";
import {MatchingEngine} from "../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../src/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../src/mock/WETH9.sol";

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
        matchingEngine.initialize(address(orderbookFactory), address(booker), address(weth));

        // setup spread
        matchingEngine.setDefaultSpread(2000000, 2000000);
        matchingEngine.setBaseFee(300000);

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
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 40000e18);
    }

    function _showOrderbook(address base, address quote) internal view {
        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(base, quote);
        console.log("Bid Head: ", bidHead);
        console.log("Ask Head: ", askHead);
        uint256[] memory bidPrices = matchingEngine.getPrices(address(base), address(quote), true, 20);
        uint256[] memory askPrices = matchingEngine.getPrices(address(base), address(quote), false, 20);
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log("AskPrice: ", askPrices[i]);
            console.log("Ask Orders: ");
            uint32[] memory askOrderIds =
                matchingEngine.getOrderIds(address(base), address(quote), false, askPrices[i], 10);
            ExchangeOrderbook.Order[] memory askOrders =
                matchingEngine.getOrders(address(base), address(quote), false, askPrices[i], 10);
            for (uint256 j = 0; j < 10; j++) {
                console.log(askOrderIds[j], askOrders[j].owner, askOrders[j].depositAmount);
            }
        }

        console.log("Bid prices: ");
        for (uint256 i = 0; i < 6; i++) {
            console.log("Bid Price: ", bidPrices[i]);
            console.log("Bid Orders: ");
            uint32[] memory bidOrderIds =
                matchingEngine.getOrderIds(address(base), address(quote), false, bidPrices[i], 10);
            ExchangeOrderbook.Order[] memory bidOrders =
                matchingEngine.getOrders(address(base), address(quote), true, bidPrices[i], 10);
            for (uint256 j = 0; j < 10; j++) {
                console.log(bidOrderIds[j], bidOrders[j].owner, bidOrders[j].depositAmount);
            }
        }
    }

    function _initOrderbook() internal {}
}
