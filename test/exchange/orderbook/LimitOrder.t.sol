pragma solidity >=0.8;

import {MockToken} from "../../../src/mock/MockToken.sol";
import {MockBase} from "../../../src/mock/MockBase.sol";
import {MockQuote} from "../../../src/mock/MockQuote.sol";
import {MockBTC} from "../../../src/mock/MockBTC.sol";
import {ErrToken} from "../../../src/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../src/exchange/orderbooks/Orderbook.sol";
import {IOrderbook} from "../../../src/exchange/interfaces/IOrderbook.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract LimitOrderTest is BaseSetup {
    function testLimitTradeWithDiffDecimals() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8);
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1e8,
            1e8,
            true,
            2,
            trader1
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1e8,
            1e18,
            true,
            2,
            trader2
        );
    }

    function testLimitTrade() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 1e8);
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1e8,
            100e18,
            true,
            2,
            trader1
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1e8,
            100e18,
            true,
            2,
            trader2
        );
    }

    function testLimitBuyETH() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(weth), 1e8);
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            trader1
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
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
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testLimitSellETH() public {
        super.setUp();
        matchingEngine.addPair(address(weth), address(token1), 1e8);
        matchingEngine.addPair(address(token1), address(weth), 1e8);
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitSellETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            trader1
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
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
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testLimitBuyETHMakingNewBidHead() public {
        super.setUp();
        matchingEngine.addPair(address(weth), address(token1), 1e8);
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.startPrank(trader1);

        matchingEngine.limitBuy(
            address(weth),
            address(token1),
            1e8,
            1e18,
            true,
            5,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        uint256 mktPrice = matchingEngine.mktPrice(
            address(weth),
            address(token1)
        );
        console.log(mktPrice);
        matchingEngine.limitBuy(
            address(weth),
            address(token1),
            294900000001,
            1e18,
            true,
            5,
            trader1
        );
    }

    // limit order is possible on out of spread range, but it is not matched
    function testLimitOrderOutOfSpreadRange() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 1e8);
        vm.prank(trader1);
        // mktprice is setup with lmp
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1e8,
            1e18,
            true,
            5,
            trader1
        );
    }

    function _setupVolatilityTest()
        internal
        returns (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        )
    {
        super.setUp();
        base = new MockBase("Base Token", "BASE");
        quote = new MockQuote("Quote Token", "QUOTE");
        base.mint(trader1, type(uint256).max);
        quote.mint(trader1, type(uint256).max);
        matchingEngine.addPair(address(base), address(quote), 1e8);
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
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        uint256 lmp = IOrderbook(
            matchingEngine.getPair(address(base), address(quote))
        ).lmp();
        up = (lmp * (10000 + 200)) / 10000;
        down = (lmp * (10000 - 200)) / 10000;
        return (base, quote, book, bidHead, askHead, up, down);
    }

    function _detLimitBuyMakePrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price, uint256 lmp) {
        uint256 up;
        lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return (lp >= up ? up : lp, lmp);
            }
            return (lp, lmp);
        } else if (askHead == 0 && bidHead != 0) {
            up = (bidHead * (10000 + spread)) / 10000;
            return (lp >= up ? up : lp, lmp);
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                up = lp >= up ? up : lp;
                return (up >= askHead ? askHead : up, lmp);
            }
            up = (askHead * (10000 + spread)) / 10000;
            up = lp >= up ? up : lp;
            return (up >= askHead ? askHead : up, lmp);
        } else {
            // First, set upper limit on make price for market suspenstion
            up = lp >= lmp ? lp : lmp;
            // upper limit on make price must not go above ask price
            return (up >= askHead ? askHead : up, lmp);
        }
    }

    function _detLimitSellMakePrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price, uint256 lmp) {
        uint256 down;
        lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return (lp <= down ? down : lp, lmp);
            }
            return (lp, lmp);
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return (lp <= down ? down : lp, lmp);
            }
            down = (bidHead * (10000 - spread)) / 10000;
            return (lp <= down ? down : lp, lmp);
        } else if (askHead != 0 && bidHead == 0) {
            down = (askHead * (10000 - spread)) / 10000;
            down = lp <= down ? down : lp;
            return (down <= bidHead ? bidHead : down, lmp);
        } else {
            // First, set lower limit on down price for market suspenstion
            down = lp <= lmp ? lp : lmp;
            // lower limit price on sell cannot be lower than bid head price
            return (down <= bidHead ? bidHead : down, lmp);
        }
    }

    // on limit sell, if limit price is higher than market price + ranged price, order is made with limit price.
    function testLimitSellVolatilityOutOfRange() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        // check limit price is higher than up
        uint256 limitPrice = (1e11 * (10000 + 1000)) / 10000;
        console.log(limitPrice, up);
        assert(limitPrice > up);
        (uint256 result, uint lmp) = _detLimitSellMakePrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        assert(result == limitPrice);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitSell(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                trader1
            );
        assert(makePrice == result);
    }

    // on limit sell, if limit price is lower than market price - ranged price, order is made with market price - ranged price.
    function testLimitSellVolatilityDown() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        // check limit price is higher than up
        uint256 limitPrice = (1e8 * (10000 - 1000)) / 10000;
        console.log(limitPrice, down);
        assert(limitPrice < down);
        (uint256 result, uint lmp) = _detLimitSellMakePrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        assert(result == down);
        uint256 mp = IOrderbook(address(book)).lmp();
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitSell(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                trader1
            );
        assert(makePrice == result);
        assert(makePrice < mp);
    }

    // on limit buy, if limit price is higher than market price + ranged price, order is made with market price + ranged price.
    function testLimitBuyVolatilityUp() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        // check limit price is higher than up
        uint256 limitPrice = (1e11 * (10000 + 1000)) / 10000;
        console.log(limitPrice, up);
        assert(limitPrice > up);
        (uint256 result, uint lmp) = _detLimitBuyMakePrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        uint256 mp = IOrderbook(address(book)).lmp();
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitBuy(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                trader1
            );
        assert(makePrice == result);
        assert(makePrice > mp);
    }

    // on limit buy, if limit price is lower than market price - ranged price, order is made with limit price.
    function testLimitBuyVolatilityLimitPrice() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        // check limit price is higher than up
        uint256 limitPrice = (1e8 * (10000 - 1000)) / 10000;
        console.log(limitPrice, down);
        assert(limitPrice < down);
        (uint256 result, uint lmp) = _detLimitBuyMakePrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        assert(result == limitPrice);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitBuy(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                trader1
            );
        assert(makePrice == result);
    }

    // on limit sell, if limit price is lower than market price - ranged price, order is made with limit price.
    function testLimitSellVolatilityLimitPrice() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            5,
            trader1
        );
    }

    function testLimitBuyNoSuspensionWhenBidAskHeadExists() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        // set up a limit buy/sell order
         matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e7,
            1e18,
            true,
            5,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e11,
            1e18,
            true,
            5,
            trader1
        );
        // set up a limit buy order to match the limit sell
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e10,
            1e18,
            true,
            8,
            trader1
        );

        assert(matchingEngine.mktPrice(address(base), address(quote)) == 1e10);
    }

    function testLimitBuySuspensionWhenBidAskHeadExistsAfterClearingHead() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        // set up a limit buy/sell order
         matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e7,
            1e18,
            true,
            5,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e11,
            1e18,
            true,
            5,
            trader1
        );

        // set up a limit buy order to match the limit sell
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e12,
            1e24,
            true,
            8,
            trader1
        );

        assert(matchingEngine.mktPrice(address(base), address(quote)) == 102e9);
    }

    function testLimitSellNoSuspensionWhenBidAskHeadExists() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        // set up a limit sell order
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            5,
            trader1
        );
        matchingEngine.limitSell(
             address(base),
            address(quote),
            1e11,
            1e18,
            true,
            5,
            trader1
        );

        // set up a limit buy order to match the limit sell
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e7,
            1e20,
            true,
            8,
            trader1
        );

        assert(matchingEngine.mktPrice(address(base), address(quote)) == 1e7);
    }

    function testLimitSellSuspensionWhenBidAskHeadExistsAfterClearingHead() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        // set up a limit buy/sell order
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            5,
            trader1
        );
        matchingEngine.limitSell(
             address(base),
            address(quote),
            1e11,
            1e18,
            true,
            5,
            trader1
        );
        
        // set up a limit buy order to match the limit sell
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e5,
            1e24,
            true,
            8,
            trader1
        );

        assert(matchingEngine.mktPrice(address(base), address(quote)) == 98e4);
    }

    function testLimitBuyAllowsBelowLMP() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8-1,
            1e18,
            true,
            5,
            trader1
        );

        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8+1,
            1e18,
            true,
            5,
            trader1
        );

        (uint256 lp, uint256 matched, uint32 id) = matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e5,
            1e18,
            true,
            5,
            trader1
        );

        assert(lp == 1e5);
    }

    function testLimitSellAllowsAboveLMP() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 bidHead,
            uint256 askHead,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();

        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8-1,
            1e18,
            true,
            5,
            trader1
        );

        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8+1,
            1e18,
            true,
            5,
            trader1
        );

        (uint256 lp, uint256 matched, uint32 id) = matchingEngine.limitSell(
            address(base),
            address(quote),
            1e11,
            1e18,
            true,
            5,
            trader1
        );

        assert(lp == 1e11);
    }
}
