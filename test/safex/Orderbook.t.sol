pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {Utils} from "../utils/Utils.sol";
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";
import {NewOrderOrderbook} from "../../contracts/safex/libraries/NewOrderOrderbook.sol";

contract BaseSetup is Test {
    Utils public utils;
    MatchingEngine public matchingEngine;

    OrderbookFactory public orderbookFactory;
    Orderbook public book;
    MockToken public token1;
    MockToken public token2;
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
        token1 = new MockToken("Token 1", "TKN1");
        token2 = new MockToken("Token 2", "TKN2");
        btc = new MockBTC("Bitcoin", "BTC");

        token1.mint(trader1, 100000e18);
        token2.mint(trader1, 100000e18);
        btc.mint(trader1, 100000e8);
        token1.mint(trader2, 100000e18);
        token2.mint(trader2, 100000e18);
        btc.mint(trader2, 100000e8);
        feeToken = new MockToken("Fee Token", "FEE");
        feeToken.mint(booker, 40000e18);
        matchingEngine = new MatchingEngine();
        orderbookFactory = new OrderbookFactory();
        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(feeToken),
            30000
        );
        matchingEngine.setFeeTo(booker);
        matchingEngine.setFee(3, 1000);

        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10000e18);
        vm.prank(trader1);
        token2.approve(address(matchingEngine), 10000e18);
        vm.prank(trader1);
        btc.approve(address(matchingEngine), 10000e8);
        vm.prank(trader2);
        token1.approve(address(matchingEngine), 10000e18);
        vm.prank(trader2);
        token2.approve(address(matchingEngine), 10000e18);
        vm.prank(trader2);
        btc.approve(address(matchingEngine), 10000e8);
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 40000e18);
    }
}

// test cases for orderbooks
contract OrderbookTest is BaseSetup {
    function testAddPair() public {
        // create orderbook
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
    }

    function testLimitTradeWithDiffDecimals() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getBookByPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1e8,
            1e8,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1e18,
            1e8,
            true,
            2,
            0
        );
    }

    function testLimitTrade() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1e8,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1e8,
            true,
            2,
            0
        );
    }

    function testOrderbookAccess() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.setFee(0, 10);
        vm.prank(trader1);
        vm.expectRevert();
        book.placeBid(trader1, 1e8, 2);
    }

    function testInvalidConversion() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.setFee(0, 10);
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getBookByPair(address(token1), address(token2))
        );
        console.log("Buy and sell with one price (Fee off)");
        vm.prank(trader1);
        uint256 trader1Token1BalanceBeforeTrade = token1.balanceOf(
            address(trader1)
        );
        uint256 trader1Token2BalanceBeforeTrade = token2.balanceOf(
            address(trader1)
        );
        uint256 trader2Token1BalanceBeforeTrade = token1.balanceOf(
            address(trader2)
        );
        uint256 trader2Token2BalanceBeforeTrade = token2.balanceOf(
            address(trader2)
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        uint256 trader1Token1BalanceAfterTrade = token1.balanceOf(
            address(trader1)
        );
        uint256 trader1Token2BalanceAfterTrade = token2.balanceOf(
            address(trader1)
        );
        uint256 trader2Token1BalanceAfterTrade = token1.balanceOf(
            address(trader2)
        );
        uint256 trader2Token2BalanceAfterTrade = token2.balanceOf(
            address(trader2)
        );
        uint256 diffToken1Trader1 = trader1Token1BalanceAfterTrade -
            trader1Token1BalanceBeforeTrade;
        uint256 diffToken2Trader1 = trader1Token2BalanceBeforeTrade -
            trader1Token2BalanceAfterTrade;
        uint256 diffToken1Trader2 = trader2Token1BalanceBeforeTrade -
            trader2Token1BalanceAfterTrade;
        uint256 diffToken2Trader2 = trader2Token2BalanceAfterTrade -
            trader2Token2BalanceBeforeTrade;
        console.log("trader1 received Token1: ", diffToken1Trader1);
        console.log("trader1 spent Token2:    ", diffToken2Trader1);
        console.log("trader2 spent Token1:    ", diffToken1Trader2);
        console.log("trader1 received Token2: ", diffToken2Trader2);
        console.log(
            "------------------------------------------------------------------------"
        );
        console.log("Sell and buy with one price (Fee off)");
        trader1Token1BalanceBeforeTrade = token1.balanceOf(address(trader1));
        trader1Token2BalanceBeforeTrade = token2.balanceOf(address(trader1));
        trader2Token1BalanceBeforeTrade = token1.balanceOf(address(trader2));
        trader2Token2BalanceBeforeTrade = token2.balanceOf(address(trader2));
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        trader1Token1BalanceAfterTrade = token1.balanceOf(address(trader1));
        trader1Token2BalanceAfterTrade = token2.balanceOf(address(trader1));
        trader2Token1BalanceAfterTrade = token1.balanceOf(address(trader2));
        trader2Token2BalanceAfterTrade = token2.balanceOf(address(trader2));
        diffToken1Trader1 =
            trader1Token1BalanceAfterTrade -
            trader1Token1BalanceBeforeTrade;
        diffToken2Trader1 =
            trader1Token2BalanceBeforeTrade -
            trader1Token2BalanceAfterTrade;
        diffToken1Trader2 =
            trader2Token1BalanceBeforeTrade -
            trader2Token1BalanceAfterTrade;
        diffToken2Trader2 =
            trader2Token2BalanceAfterTrade -
            trader2Token2BalanceBeforeTrade;
        console.log("trader1 received Token1: ", diffToken1Trader1);
        console.log("trader1 spent Token2:    ", diffToken2Trader1);
        console.log("trader2 spent Token1:    ", diffToken1Trader2);
        console.log("trader1 received Token2: ", diffToken2Trader2);
    }

    function testManipulateMarketPrice() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            90e8,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            110e8,
            true,
            2,
            0
        );
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        console.log("Market price before manipulation: ", book.mktPrice());
        vm.prank(attacker);
        //book.placeBid(address(trader1), 1e7, 100e18);
        //vm.prank(attacker);
        //book.placeAsk(address(trader1), 1e8, 100e18);
        console.log("Market price after manipulation:", book.mktPrice());
    }

    function testNewOrderLinkedListOutOfGas() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);

        // placeBid or placeAsk two of them is using the _insert function it will revert
        // because the program will enter the (price < last) statement
        // and eventually, it will cause an infinite loop.
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            2,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            1,
            true,
            2,
            0
        );
    }

    function testNewOrderLinkedListOutOfGasPlaceBid() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        // We can create the same example with placeBid function
        // This time the program will enter the while (price > last && last != 0) statement
        // and it will cause an infinite loop.
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            2,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            6,
            true,
            2,
            0
        );
    }

    function testNewOrderOrderbookOutOfGas() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            1,
            true,
            2,
            0
        );
    }

    function testConvertOnSameDecimal() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            100000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            5,
            0
        );
        console.log("Base token decimal: ", 18);
        console.log("Quote token decimal: ", 18);
        uint256 converted1 = matchingEngine.convert(
            address(token1),
            address(token2),
            1e20,
            true
        ); // 100 * 1e18 quote token to base token
        uint256 converted2 = matchingEngine.convert(
            address(token1),
            address(token2),
            1e20,
            false
        ); // 100 * 1e18 in base token to quote token
        console.log("quote token to converted base token: ", converted1 / 1e18);
        console.log("base token to converted quote token: ", converted2 / 1e18);
    }

    function testConvertOnDifferentDecimalWhereBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            10,
            500000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            10,
            100000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            10,
            500000000,
            true,
            2,
            0
        );
        console.log("Base token decimal: ", 18);
        console.log("Quote token decimal: ", 8);
        uint256 converted1 = matchingEngine.convert(
            address(token1),
            address(btc),
            1e10,
            true
        ); // 100 * 1e8(decimal) quote token to base token
        uint256 converted2 = matchingEngine.convert(
            address(token1),
            address(btc),
            1e20,
            false
        ); // 100 * 1e18(decimal) in base token to quote token
        console.log("quote token to converted base token: ", converted1 / 1e18);
        console.log("base token to converted quote token: ", converted2 / 1e8);
    }

    function testConvertOnDifferentDecimalWhereNotBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(btc), address(token1));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(btc), address(token1))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(btc),
            address(token1),
            10,
            500000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(btc),
            address(token1),
            10,
            100000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(btc),
            address(token1),
            10,
            500000000,
            true,
            2,
            0
        );
        console.log("Base token decimal: ", 8);
        console.log("Quote token decimal: ", 18);
        uint256 converted1 = matchingEngine.convert(
            address(btc),
            address(token1),
            1e20,
            true
        ); // 100 * 1e18(decimal) quote token to base token
        uint256 converted2 = matchingEngine.convert(
            address(btc),
            address(token1),
            1e10,
            false
        ); // 100 * 1e8(decimal) in base token to quote token
        console.log(
            "quote token to converted base token in decimal of 8: ",
            converted1 / 1e8
        );
        console.log(
            "base token to converted quote token in decimal of 18: ",
            converted2 / 1e18
        );
    }

    function testGetPrices() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            100000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            5,
            0
        );
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        console.log("Ask prices: ");
        for (uint i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint i = 0; i < 3; i++) {
            console.log(bidPrices[i]);
        }
    }

    function testGetOrders() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            100000000,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            500000000,
            true,
            5,
            0
        );

        console.log("Bid orders: ");
        NewOrderOrderbook.Order[] memory bidOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            500000000,
            3
        );

        for (uint i = 0; i < 3; i++) {
            console.log(bidOrders[i].owner, bidOrders[i].depositAmount);
        }
    }
}
