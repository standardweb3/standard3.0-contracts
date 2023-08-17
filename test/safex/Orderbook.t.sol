pragma solidity >=0.8;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {MockBase} from "../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../utils/Utils.sol";
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";
import {SAFEXOrderbook} from "../../contracts/safex/libraries/SAFEXOrderbook.sol";
import {IOrderbookFactory} from "../../contracts/safex/interfaces/IOrderbookFactory.sol";

contract BaseSetup is Test {
    Utils public utils;
    MatchingEngine public matchingEngine;

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
        matchingEngine.initialize(
            address(orderbookFactory),
            address(feeToken),
            address(0),
            address(booker)
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
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 40000e18);
    }
}

contract OrderbookAddPairTest is BaseSetup {
    ErrToken public err;

    function testAddPair() public {
        // create orderbook
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
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

// test cases for orderbooks
contract OrderbookMatchTest is BaseSetup {
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
            1e8,
            1e18,
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
            1e8,
            100e18,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1e8,
            100e18,
            true,
            2,
            0
        );
    }

    function testOrderbookAccess() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        vm.expectRevert();
        book.placeBid(trader1, 1e8, 2);
    }

    function testInvalidConversion() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
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
            1,
            100e18,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1,
            100e18,
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
            1,
            100e18,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1,
            100e18,
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
            90e8,
            100e18,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            110e8,
            100e18,
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

    function testSAFEXLinkedListOutOfGas() public {
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
            2,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            5,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            5,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1,
            10,
            true,
            2,
            0
        );
    }

    function testSAFEXLinkedListOutOfGasPlaceBid() public {
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
            2,
            5e7,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            5,
            2e7,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            5,
            2e7,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            6,
            2e7,
            true,
            2,
            0
        );
    }

    function testSAFEXOrderbookOutOfGas() public {
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
            5,
            2e7,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1,
            1e8,
            true,
            2,
            0
        );
    }

    function testConvertBuySellOnDifferentDecimalWhereBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(btc))
        );
        // before trade balances
        uint256 beforeTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 beforeTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 beforeTrader1T1Balance = token1.balanceOf(address(trader1));
        uint256 beforeTrader1BTCBalance = btc.balanceOf(address(trader1));

        // deposit 10000e8(9990e8 after fee) for buying 10e18 token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1000e8,
            10000e8,
            true,
            5,
            0
        );
        // deposit 10e18(9.99e18 after fee) for selling token1 for 1000 token1 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1000e8,
            10e18,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 afterTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 afterTrader1T1Balance = token1.balanceOf(address(trader1));
        uint256 afterTrader1BTCBalance = btc.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T1Balance = beforeTrader2T1Balance -
            afterTrader2T1Balance;
        uint256 diffTrader2BTCBalance = afterTrader2BTCBalance -
            beforeTrader2BTCBalance;
        uint256 diffTrader1T1Balance = afterTrader1T1Balance -
            beforeTrader1T1Balance;
        uint256 diffTrader1BTCBalance = beforeTrader1BTCBalance -
            afterTrader1BTCBalance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T1Balance,
            diffTrader2BTCBalance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T1Balance,
            diffTrader1BTCBalance
        );

        // Trader2's btc balance should be increased by 9.99e11
        assert(diffTrader2BTCBalance == 9990e8);
        // Trader2's token1 balance should be decreased by 10e18
        assert(diffTrader2T1Balance == 10e18);
        // Trader1's btc balance should be decreased by 10000e8
        assert(diffTrader1BTCBalance == 10000e8);
        // Trader1's token1 balance should be increased by 9.99e18
        assert(diffTrader1T1Balance == 9990e15);

        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
    }

    function testConvertSellBuyOnDifferentDecimalWhereBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(btc))
        );
        // before trade balances
        uint256 beforeTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 beforeTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 beforeTrader1T1Balance = token1.balanceOf(address(trader1));
        uint256 beforeTrader1BTCBalance = btc.balanceOf(address(trader1));

        // deposit 10e18(9.99e18 after fee) for selling token1 for 1000 token1 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1000e8,
            10e18,
            true,
            5,
            0
        );

        // deposit 10000e8(9990e8 after fee) for buying 10e18 token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1000e8,
            10000e8,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 afterTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 afterTrader1T1Balance = token1.balanceOf(address(trader1));
        uint256 afterTrader1BTCBalance = btc.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T1Balance = beforeTrader2T1Balance -
            afterTrader2T1Balance;
        uint256 diffTrader2BTCBalance = afterTrader2BTCBalance -
            beforeTrader2BTCBalance;
        uint256 diffTrader1T1Balance = afterTrader1T1Balance -
            beforeTrader1T1Balance;
        uint256 diffTrader1BTCBalance = beforeTrader1BTCBalance -
            afterTrader1BTCBalance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T1Balance,
            diffTrader2BTCBalance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T1Balance,
            diffTrader1BTCBalance
        );

        // Trader2's btc balance should be increased by 9.99e11
        assert(diffTrader2BTCBalance == 9990e8);
        // Trader2's token1 balance should be decreased by 10e18
        assert(diffTrader2T1Balance == 10e18);
        // Trader1's btc balance should be decreased by 10000e8
        assert(diffTrader1BTCBalance == 10000e8);
        // Trader1's token1 balance should be increased by 9.99e18
        assert(diffTrader1T1Balance == 9990e15);

        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
    }

    function testConvertBuySellOnDifferentDecimalWhereNotBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(btc), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(btc), address(token2))
        );
        // before trade balances
        uint256 beforeTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 beforeTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 beforeTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 beforeTrader1BTCBalance = btc.balanceOf(address(trader1));

        // deposit 10000e18(9990e18 after fee) for buying 10e8 token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(btc),
            address(token2),
            1000e8,
            10000e18,
            true,
            5,
            0
        );
        // deposit 10e8(9.99e8 after fee) for selling token1 for 1000 token1 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(btc),
            address(token2),
            1000e8,
            10e8,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 afterTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 afterTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 afterTrader1BTCBalance = btc.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T2Balance = afterTrader2T2Balance -
            beforeTrader2T2Balance;
        uint256 diffTrader2BTCBalance = beforeTrader2BTCBalance -
            afterTrader2BTCBalance;
        uint256 diffTrader1T2Balance = beforeTrader1T2Balance -
            afterTrader1T2Balance;
        uint256 diffTrader1BTCBalance = afterTrader1BTCBalance -
            beforeTrader1BTCBalance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T2Balance,
            diffTrader2BTCBalance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T2Balance,
            diffTrader1BTCBalance
        );

        // Trader2's token2 balance should be increased by 9.99e21
        assert(diffTrader2T2Balance == 9990e18);

        // Trader2's token1 balance should be decreased by 10e8
        assert(diffTrader2BTCBalance == 10e8);
        // Trader1's token2 balance should be decreased by 10000e18
        assert(diffTrader1T2Balance == 10000e18);
        // Trader1's token1 balance should be increased by 9.99e8
        assert(diffTrader1BTCBalance == 9990e5);

        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
    }

    function testConvertSellBuyOnDifferentDecimalWhereNotBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(btc), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(btc), address(token2))
        );
        // before trade balances
        uint256 beforeTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 beforeTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 beforeTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 beforeTrader1BTCBalance = btc.balanceOf(address(trader1));

        // deposit 10e8(9.99e8 after fee) for selling token1 for 1000 token1 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(btc),
            address(token2),
            1000e8,
            10e8,
            true,
            5,
            0
        );
        // deposit 10000e18(9990e18 after fee) for buying 10e8 token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(btc),
            address(token2),
            1000e8,
            10000e18,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 afterTrader2BTCBalance = btc.balanceOf(address(trader2));
        uint256 afterTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 afterTrader1BTCBalance = btc.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T2Balance = afterTrader2T2Balance -
            beforeTrader2T2Balance;
        uint256 diffTrader2BTCBalance = beforeTrader2BTCBalance -
            afterTrader2BTCBalance;
        uint256 diffTrader1T2Balance = beforeTrader1T2Balance -
            afterTrader1T2Balance;
        uint256 diffTrader1BTCBalance = afterTrader1BTCBalance -
            beforeTrader1BTCBalance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T2Balance,
            diffTrader2BTCBalance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T2Balance,
            diffTrader1BTCBalance
        );

        // Trader2's token2 balance should be increased by 9.99e21
        assert(diffTrader2T2Balance == 9990e18);

        // Trader2's token1 balance should be decreased by 10e8
        assert(diffTrader2BTCBalance == 10e8);
        // Trader1's token2 balance should be decreased by 10000e18
        assert(diffTrader1T2Balance == 10000e18);
        // Trader1's token1 balance should be increased by 9.99e8
        assert(diffTrader1BTCBalance == 9990e5);

        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
    }

    function testConvertBuySellOnSameDecimal() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        // before trade balances
        uint256 beforeTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 beforeTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 beforeTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 beforeTrader1T1Balance = token1.balanceOf(address(trader1));

        // deposit 10000e18(9990e18 after fee) for buying token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            5,
            0
        );
        // deposit 10e18(9.99e18 after fee) for selling token1 for 1000 token2 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            10e18,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 afterTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 afterTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 afterTrader1T1Balance = token1.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T2Balance = afterTrader2T2Balance -
            beforeTrader2T2Balance;
        uint256 diffTrader2T1Balance = beforeTrader2T1Balance -
            afterTrader2T1Balance;
        uint256 diffTrader1T2Balance = beforeTrader1T2Balance -
            afterTrader1T2Balance;
        uint256 diffTrader1T1Balance = afterTrader1T1Balance -
            beforeTrader1T1Balance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T2Balance,
            diffTrader2T1Balance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T2Balance,
            diffTrader1T1Balance
        );

        // Trader2's token2 balance should be increased by 9.99e21
        assert(diffTrader2T2Balance == 9990e18);

        // Trader2's token1 balance should be decreased by 10e18
        assert(diffTrader2T1Balance == 10e18);
        // Trader1's token2 balance should be decreased by 10000e18
        assert(diffTrader1T2Balance == 10000e18);
        // Trader1's token1 balance should be increased by 9.99e18
        assert(diffTrader1T1Balance == 9990e15);

        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log("bidHead: ", bidHead);
        console.log("askHead: ", askHead);
    }

    function testConvertSellBuyOnSameDecimal() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        // before trade balances
        uint256 beforeTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 beforeTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 beforeTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 beforeTrader1T1Balance = token1.balanceOf(address(trader1));

        // deposit 10e18(9.99e18 after fee) for selling token1 for 1000 token2 * amount
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            10e18,
            true,
            5,
            0
        );
        // deposit 10000e18(9990e18 after fee) for buying token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            5,
            0
        );

        // after trade balances
        uint256 afterTrader2T2Balance = token2.balanceOf(address(trader2));
        uint256 afterTrader2T1Balance = token1.balanceOf(address(trader2));
        uint256 afterTrader1T2Balance = token2.balanceOf(address(trader1));
        uint256 afterTrader1T1Balance = token1.balanceOf(address(trader1));

        // differences
        uint256 diffTrader2T2Balance = afterTrader2T2Balance -
            beforeTrader2T2Balance;
        uint256 diffTrader2T1Balance = beforeTrader2T1Balance -
            afterTrader2T1Balance;
        uint256 diffTrader1T2Balance = beforeTrader1T2Balance -
            afterTrader1T2Balance;
        uint256 diffTrader1T1Balance = afterTrader1T1Balance -
            beforeTrader1T1Balance;

        console.log(
            "Trader2 diffs: ",
            diffTrader2T2Balance,
            diffTrader2T1Balance
        );
        console.log(
            "Trader1 diffs: ",
            diffTrader1T2Balance,
            diffTrader1T1Balance
        );

        // Trader2's token2 balance should be increased by 9.99e21
        assert(diffTrader2T2Balance == 9990e18);

        // Trader2's token1 balance should be decreased by 10e18
        assert(diffTrader2T1Balance == 10e18);
        // Trader1's token2 balance should be decreased by 10000e18
        assert(diffTrader1T2Balance == 10000e18);
        // Trader1's token1 balance should be increased by 9.99e18
        assert(diffTrader1T1Balance == 9990e15);
    }

    function testGetOrderInsertion() public {
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
            100000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
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
            100000000,
            8,
            true,
            2,
            0
        );
        SAFEXOrderbook.Order[] memory orders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            100000000,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders[i].owner, orders[i].depositAmount);
        }
    }

    function testCancelOrderDeletion() public {
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
            100000000,
            10,
            true,
            2,
            0
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );

        SAFEXOrderbook.Order[] memory orders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            100000000,
            4
        );
        console.log("Ask Orders before cancel: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders[i].owner, orders[i].depositAmount);
        }

        // cancel order

        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            100000000,
            3,
            false,
            0
        );

        SAFEXOrderbook.Order[] memory orders2 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            100000000,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders2[i].owner, orders2[i].depositAmount);
        }
    }

    function testRemoveHeadOnMatch() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            2,
            0
        );
        console.log("Ask Orders: ");
        SAFEXOrderbook.Order[] memory askOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders0[i].owner, askOrders0[i].depositAmount);
        }
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            false,
            2,
            0
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        console.log("Ask Orders: ");
        SAFEXOrderbook.Order[] memory askOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders[i].owner, askOrders[i].depositAmount);
        }
        console.log(book.isEmpty(false, 1000e8));
        //console.log(book.checkRequired());
        vm.prank(trader1);

        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            2,
            0
        );
    }

    function testMatchOrders() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader2);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            3000e18,
            true,
            2,
            0
        );

        SAFEXOrderbook.Order[] memory bidOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            true,
            1000e8,
            4
        );
        console.log("Bid Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidOrders0[i].owner, bidOrders0[i].depositAmount);
        }

        SAFEXOrderbook.Order[] memory askOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders0[i].owner, askOrders0[i].depositAmount);
        }

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            1e18,
            true,
            2,
            0
        );

        SAFEXOrderbook.Order[] memory bidOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            true,
            1000e8,
            4
        );
        console.log("Bid Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidOrders[i].owner, bidOrders[i].depositAmount);
        }

        SAFEXOrderbook.Order[] memory askOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders[i].owner, askOrders[i].depositAmount);
        }
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);

        vm.prank(trader2);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            1e18,
            true,
            2,
            0
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
            500000000,
            10,
            true,
            2,
            0
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            90000000,
            10,
            true,
            5,
            0
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            10,
            true,
            5,
            0
        );
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
    }

    function testGetPriceInsertion() public {
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
            100000000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100200000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100100000000,
            10,
            true,
            5,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            99800000000,
            998,
            true,
            5,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            99900000000,
            999,
            true,
            5,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            99700000000,
            997,
            true,
            5,
            0
        );
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
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
            500000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            10,
            true,
            5,
            0
        );

        console.log("Bid orders: ");
        SAFEXOrderbook.Order[] memory bidOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            500000000,
            3
        );

        for (uint256 i = 0; i < 3; i++) {
            console.log(bidOrders[i].owner, bidOrders[i].depositAmount);
        }
    }

    function testGetAskHead() public {
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
            500000000,
            10,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0
        );
        console.log("Ask Head:");
        console.log(book.askHead());
    }

    function testGetPairs() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        IOrderbookFactory.Pair[] memory pairs = matchingEngine.getPairs(0, 20);
        console.log("Pairs:");
        console.log(pairs[0].base, pairs[0].quote);
    }

    function testGetPairNames() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        IOrderbookFactory.Pair[] memory pairs = matchingEngine.getPairs(0, 20);
        console.log("Pairs:");
        console.log(pairs[0].base, pairs[0].quote);
        string[] memory names = matchingEngine.getPairNames(0, 20);
        console.log(names[0]);
    }

    function testAmountIsZero() public {
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
            500000000,
            10,
            true,
            2,
            0
        );
    }

    function testPairAlreadyAdded() public {
        super.setUp();
        vm.prank(booker);
        MockToken token3 = new MockToken("Mock3", "MOCK3");
        matchingEngine.addPair(address(token1), address(token3));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token3))
        );
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(token3));
    }

    function testPairSameBaseQuote() public {
        super.setUp();
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(token1));
    }

    function testPairOrderbookQuery() public {
        super.setUp();
        vm.prank(booker);
        MockToken token3 = new MockToken("Mock3", "MOCK3");
        matchingEngine.addPair(address(token1), address(token3));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token3))
        );
    }
}
