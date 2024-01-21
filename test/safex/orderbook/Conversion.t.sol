pragma solidity >=0.8;

import {MockToken} from "../../../contracts/mock/MockToken.sol";
import {MockBase} from "../../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../contracts/safex/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../contracts/safex/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../contracts/safex/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {Treasury} from "../../../contracts/sabt/Treasury.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

// test cases for orderbooks
contract ConversionTest is BaseSetup {
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

    function testConvertBuySellOnDifferentDecimalWhereBaseBQuote() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        book = Orderbook(
            payable(
                orderbookFactory.getBookByPair(address(token1), address(btc))
            )
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
            payable(
                orderbookFactory.getBookByPair(address(token1), address(btc))
            )
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
            payable(
                orderbookFactory.getBookByPair(address(btc), address(token2))
            )
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
            payable(
                orderbookFactory.getBookByPair(address(btc), address(token2))
            )
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
            payable(
                orderbookFactory.getBookByPair(address(token1), address(token2))
            )
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
        console.log("flag");
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
            payable(
                orderbookFactory.getBookByPair(address(token1), address(token2))
            )
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

    

    

    function testAmountIsZero() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            payable(
                orderbookFactory.getBookByPair(address(token1), address(token2))
            )
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

}
