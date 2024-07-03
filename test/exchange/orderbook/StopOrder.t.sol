pragma solidity >=0.8;

import {MockToken} from "../../../src/mock/MockToken.sol";
import {MockBase} from "../../../src/mock/MockBase.sol";
import {MockQuote} from "../../../src/mock/MockQuote.sol";
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

contract StopOrderTest is BaseSetup {
    function _setupStopOrderTest()
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
        matchingEngine.addPair(address(base), address(quote), 1e8);
        matchingEngine.addPair(address(weth), address(quote), 1e8);
        matchingEngine.addPair(address(base), address(weth), 1e8);
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
            0,
            trader1
        );
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );
        mp = matchingEngine.mktPrice(address(base), address(quote));
        up = (mp * (10000 + 200)) / 10000;
        down = (mp * (10000 - 200)) / 10000;
        return (base, quote, book, mp, up, down);
    }
    // test if stop buy order is placed in the orderbook above askHead and it does not match when askHead is below the stop price
    function testStopBuyAboveAskHeadDoesNotMatchWhenStopPriceAboveAskHead()
        public
    {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.stopBuy(
            address(base),
            address(quote),
            1e8 + 10,
            1e18,
            true,
            2,
            0,
            trader1
        );
    }

    // test if stop buy order is stored in the orderbook above askHead and it matches when askHead is above the stop price
    function testStopBuyAboveAskHeadMatchesWhenStopPriceAboveAskHead() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.stopBuy(
            address(base),
            address(quote),
            1e8 + 10,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.marketBuy(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketSell(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketSell(address(base), address(quote), 1e18, true, 2, 0, trader1);
    }

    // test if stop sell order is stored in the orderbook below bidHead and it does not match when bidHead is above the stop price
    function testStopSellBelowBidHeadDoesNotMatchStopPriceAboveBidHead()
        public
    {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.stopSell(
            address(base),
            address(quote),
            1e8 - 10,
            1e18,
            true,
            2,
            0,
            trader1
        );
    }

    // test if stop sell order is stored in the orderbook below bidHead and it matches when bidHead is below the stop price
    function testStopSellBelowBidHeadMatchesWhenStopPriceBelowBidHead()
        public
    {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.stopSell(
            address(base),
            address(quote),
            1e8 - 10,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.marketSell(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketBuy(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketBuy(address(base), address(quote), 1e18, true, 2, 0, trader1);
    }

    // test if stop buy order eth works
    function testStopBuyETHWorks() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.stopBuyETH{value: 1e18}(
            address(base),
            1e8,
            true,
            2,
            0,
            trader1
        );
    }

    // test if stop sell order eth works
    function testStopSellETHWorks() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.stopSellETH{value: 1e18}(
            address(quote),
            1e8,
            true,
            2,
            0,
            trader1
        );
    }

    // test if stop buy order is stored in the orderbook, and cancelling it would not jam the orderbook
    function testStopBuyCancellJammingOrderbook() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        (uint256 makePrice, uint256 remaining, uint32 makeId) = matchingEngine.stopSell(
            address(base),
            address(quote),
            1e8 - 10,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.cancelOrder(address(base), address(quote), false, makeId);

        matchingEngine.marketSell(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketBuy(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketBuy(address(base), address(quote), 1e18, true, 2, 0, trader1);
    }

    // test if stop sell order is stored in the orderbook, and cancelling it would not jam the orderbook
    function testStopSellCancelJammingOrderbook() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        (uint256 _makePrice, uint256 _remaining, uint32 makeId) = matchingEngine.stopBuy(
            address(base),
            address(quote),
            1e8 + 10,
            1e18,
            true,
            2,
            0,
            trader1
        );

        matchingEngine.cancelOrder(address(base), address(quote), true, makeId);


        matchingEngine.marketBuy(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketSell(address(base), address(quote), 1e19, true, 2, 0, trader1);
        matchingEngine.marketSell(address(base), address(quote), 1e18, true, 2, 0, trader1);
    }

    // test if stop buy order acts same as limit buy order if the stop price is below bidHead
    function testStopBuyActsSameLimitBuyWhenStopPriceBelowBidHead() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.stopBuyETH{value: 1e18}(
            address(base),
            1e7,
            true,
            2,
            0,
            trader1
        );
    }

    // test if stop sell order acts same as limit sell order if the stop price is above askHead
    function testStopSellActsSameLimitSellWhenStopPriceAboveAskHead() public {
         (
            MockBase base,
            MockQuote quote,
            Orderbook pair,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupStopOrderTest();

        matchingEngine.stopSellETH{value: 1e18}(
            address(quote),
            1e9,
            true,
            2,
            0,
            trader1
        );
    }
}
