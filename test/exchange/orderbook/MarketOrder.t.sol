pragma solidity >=0.8;

import {MockToken} from "../../../src/mock/MockToken.sol";
import {MockBase} from "../../../src/mock/MockBase.sol";
import {MockQuote} from "../../../src/mock/MockQuote.sol";
import {MockUSDC} from "../../../src/mock/MockUSDC.sol";
import {MockBTC} from "../../../src/mock/MockBTC.sol";
import {ErrToken} from "../../../src/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../src/exchange/orderbooks/OrderbookFactory.sol";
import {IOrderbook} from "../../../src/exchange/interfaces/IOrderbook.sol";
import {Orderbook} from "../../../src/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract MarketOrderTest is BaseSetup {
    function testMarketBuyETH() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(weth), 1e8, 0, address(token1));
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(weth),
            1e8,
            1e18,
            true,
            5,
            trader1
        );
        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(
            address(token1),
            address(weth)
        );
        console.log(bidHead, askHead);
        vm.prank(trader1);
        matchingEngine.marketBuyETH{value: 1e18}(
            address(token1),
            true,
            5,
            trader1,
            200
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
        vm.prank(trader1);
        matchingEngine.marketSell(
            address(token1),
            address(weth),
            1e18,
            true,
            5,
            trader1,
            200
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testMarketSellETH() public {
        super.setUp();
        matchingEngine.addPair(address(weth), address(token1), 1e8, 0, address(weth));
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(weth),
            address(token1),
            1e8,
            1e18,
            true,
            5,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.marketSellETH{value: 1e18}(
            address(token1),
            true,
            5,
            trader1,
            200
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
        vm.prank(trader1);
        matchingEngine.marketBuy(
            address(weth),
            address(token1),
            1e18,
            true,
            5,
            trader1,
            200
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testCancelJammingOrderbook() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 1000e8, 0, address(token1));
        vm.prank(booker);

        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );

        vm.prank(trader1);
        token1.approve(address(matchingEngine), 1000000000000000000e18);

        // deposit 10000e18(9990e18 after fee) for buying token1 for 1000 token2 * amount
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            1000e18,
            true,
            5,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1100e8,
            1000e18,
            true,
            5,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1200e8,
            1000e18,
            true,
            5,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.cancelOrder(address(token1), address(token2), false, 1);
        vm.prank(trader1);
        matchingEngine.cancelOrder(address(token1), address(token2), false, 2);
        ExchangeOrderbook.Order memory order = matchingEngine.getOrder(
            address(token1),
            address(token2),
            false,
            3
        );
        console.log("Order id 3: ", order.owner, order.depositAmount);
        _showOrderbook(address(token1), address(token2));

        vm.prank(trader1);
        matchingEngine.marketBuy(
            address(token1),
            address(token2),
            //1400e8,
            3400000e18,
            true,
            5,
            trader1,
            200
        );

        console.log(
            "Mkt Price: ",
            matchingEngine.mktPrice(address(token1), address(token2))
        );

        console.log(
            "minRequired quote",
            matchingEngine.convert(address(token1), address(token2), 1, true)
        );

        console.log(
            "minRequired base",
            matchingEngine.convert(address(token1), address(token2), 1, false)
        );
    }

    function _detMarketBuyMakePrice(
        address orderbook,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 up;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return up;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (10000 + spread)) / 10000;
                return up;
            }
            up = (bidHead * (10000 + spread)) / 10000;
            return up;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return askHead >= up ? up : askHead;
            }
            return askHead;
        } else {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (10000 + spread)) / 10000;
                return askHead >= up ? up : askHead;
            }
            return askHead;
        }
    }

    function _detMarketSellMakePrice(
        address orderbook,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 down;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return down == 0 ? 1 : down;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                down = down <= bidHead ? bidHead : down;
                return down == 0 ? 1 : down;
            }
            return bidHead;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (10000 - spread)) / 10000;
                return down == 0 ? 1 : down;
            }
            down = (askHead * (10000 - spread)) / 10000;
            return down == 0 ? 1 : down;
        } else {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (10000 - spread)) / 10000;
                down = down <= bidHead ? bidHead : down;
                return down == 0 ? 1 : down;
            }
            return bidHead;
        }
    }

    function _setupVolatilityTest()
        internal
        returns (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        )
    {
        super.setUp();
        base = new MockBase("Base Token", "BASE");
        quote = new MockQuote("Quote Token", "QUOTE");
        base.mint(trader1, type(uint256).max);
        quote.mint(trader1, type(uint256).max);
        // make a price in matching engine where 1 base = 1 quote with buy and sell order
        matchingEngine.addPair(address(base), address(quote), 1e8, 0, address(base));
        vm.startPrank(trader1);
        base.approve(address(matchingEngine), type(uint256).max);
        quote.approve(address(matchingEngine), type(uint256).max);
        // make last matched price
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            trader1
        );
        mp = matchingEngine.mktPrice(address(base), address(quote));
        up = (mp * (10000 + 200)) / 10000;
        down = (mp * (10000 - 200)) / 10000;
        return (base, quote, book, mp, up, down);
    }

    // On market buy, if askHead is higher than lmp + ranged price, order is made with lmp + ranged price.
    function testMarketBuyVolatilityUp1() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp, // silence warning
            uint256 up,
            uint256 _down // silence warning
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e11,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check askHead is higher than up
        assert(askHead > up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5, trader1, 200);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market buy, if bidHead is lower than lmp + ranged price, order is lmp + ranged price
    function testMarketBuyVolatilityUp2() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp /* silence warning */,
            uint256 up,
            uint256 _down /* silence warning */
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(bidHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5,  trader1, 200);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market buy, if askHead is lower than lmp + ranged price, order is made with askHead
    function testMarketBuyVolatilityUp3() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 up,
            uint256 _down
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8 + 1,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(askHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == askHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5,  trader1, 200);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market buy, bidHead and askHead exists. if lmp + ranged price is higher than bidHead, and lmp + ranged price is lower than askHead, order is made in askHead.
    function testMarketBuyVolatilityUp4() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 up,
            uint256 _down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8 + 1,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(askHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == askHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5, trader1, 200);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    function testMarketBuyVolatilityOnSlippageLimit() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp /* silence warning */,
            uint256 up,
            uint256 _down /* silence warning */
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(bidHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            50
        );
        console.log("result: ", result);
        // check computed result
        assert(result == 100500000);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5,  trader1, 50);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    function testMarketBuyVolatilityOnSlippageLimit2() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp /* silence warning */,
            uint256 up,
            uint256 _down /* silence warning */
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(bidHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5,  trader1, 300);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market buy, if askHead is lower than lmp + ranged price, order is made with askHead
    function testMarketBuyVolatilityDown() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 _down
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            (mp * (10000 + 100)) / 10000,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check askHead is lower than up
        assert(askHead < up);
        uint256 result = _detMarketBuyMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == askHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5, trader1, 200);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market sell, if bidHead is lower than lmp - ranged price, order is made with lmp - ranged price.
    function testMarketSellVolatilityDown1() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 _up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than down
        assert(bidHead < down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == down);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                trader1,
                200
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market sell, if bidHead is lower than lmp - ranged price, order is lmp - ranged price
    function testMarketSellVolatilityDown2() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 _up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than up
        assert(bidHead < down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == down);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                trader1,
                200
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market sell, if bidHead is higher than lmp - ranged price, order is made with bidHead
    function testMarketSellVolatilityDown3() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 _up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            (mp * (10000 - 100)) / 10000,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is higher than down
        assert(bidHead > down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == bidHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine // silence warning
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                trader1,
                200
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    function testMarketSellVolatilityDownOnSlippageLimit() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 _up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than down
        assert(bidHead < down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            50
        );
        console.log("result: ", result);
        // check computed result with user input with 50bps down
        assert(result == 99500000);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                trader1,
                50
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

     function testMarketSellVolatilityDownOnSlippageLimit2() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 _up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than down
        assert(bidHead < down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result with user input with 50bps down
        assert(result == down);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                trader1,
                300
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // Check if market sell leading to zero price is fixed
    function testMarketSellSettingPriceToZero() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp,
            uint256 _up,
            uint256 _down
        ) = _setupVolatilityTest();

        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 _bidHead, uint256 _askHead) = book.heads();
        uint beforeB = quote.balanceOf(address(trader1));
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine // silence warning
            .marketSell(
                address(base),
                address(quote),
                1e8,
                false,
                5,
                trader1,
                200
            );
        uint afterB = quote.balanceOf(address(trader1));
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        console.log("market price: ", book.mktPrice());
        console.log("balance before: ", beforeB);
        console.log("balance after: ", afterB);
    }

    // Check if market buy leading to price change is fixed
    function testMarketBuySettingPriceToUp() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp, // silence warning
            uint256 _up, // silence warning
            uint256 _down // silence warning
        ) = _setupVolatilityTest();

        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 _bidHead, uint256 _askHead) = book.heads(); // silence warning
        uint beforeB = quote.balanceOf(address(trader1));
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine // silence warning
            .marketBuy(
                address(base),
                address(quote),
                1e8,
                false,
                5,
                trader1,
                200
            );
        uint afterB = quote.balanceOf(address(trader1));
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        console.log("market price: ", book.mktPrice());
        console.log("balance before: ", beforeB);
        console.log("balance after: ", afterB);
    }

    function testMarketSellVolatilityDown4() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 _mp /* silence warning */,
            uint256 _up /* silence warning */,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8 - 1,
            1e18,
            true,
            2,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e10,
            1e18,
            true,
            2,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is higher than up
        assert(bidHead >= down);
        uint256 result = _detMarketSellMakePrice(
            address(book),
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        // check computed result
        assert(result == bidHead);
        (
            uint256 makePrice,
            uint256 _placed /* silence warning */,
            uint256 _matched /* silence warning */
        ) = matchingEngine.marketSell( // silence warning
                    address(base),
                    address(quote),
                    1e8,
                    true,
                    5,
                    trader1,
                    200
                );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    function testMarketBuyAndSell() public {
        super.setUp();
        MockBase base = new MockBase("Base Token", "BASE");
        MockUSDC quote = new MockUSDC("Quote Token", "QUOTE");
        base.mint(trader1, type(uint256).max);
        quote.mint(trader1, type(uint256).max);
        // make a price in matching engine where 1 base = 1 quote with buy and sell order
        matchingEngine.addPair(address(base), address(quote), 341320000000, 0, address(base));
        vm.startPrank(trader1);
        base.approve(address(matchingEngine), type(uint256).max);
        quote.approve(address(matchingEngine), type(uint256).max);
        matchingEngine.marketBuy(
            address(base),
            address(quote),
            100000,
            true,
            5,
            trader1,
            200
        );

        matchingEngine.marketSell(
            address(base),
            address(quote),
            1e14,
            true,
            5,
            trader1,
            200
        );
    }
}
