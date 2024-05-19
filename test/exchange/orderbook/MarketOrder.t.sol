pragma solidity >=0.8;

import {MockToken} from "../../../contracts/mock/MockToken.sol";
import {MockBase} from "../../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {IOrderbook} from "../../../contracts/exchange/interfaces/IOrderbook.sol";
import {Orderbook} from "../../../contracts/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../contracts/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../contracts/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract MarketOrderTest is BaseSetup {
    function testMarketBuyETH() public {
        super.setUp();
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
            0,
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
            0,
            trader1
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
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testMarketSellETH() public {
        super.setUp();
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
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.marketSellETH{value: 1e18}(
            address(token1),
            true,
            5,
            0,
            trader1
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
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testCancelJammingOrderbook() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
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
            0,
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
            0,
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
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1,
            0
        );
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            2,
            0
        );
        ExchangeOrderbook.Order memory order = matchingEngine.getOrder(
            address(token1),
            address(token2),
            false,
            3
        );
        console.log("Order id 3: ", order.owner, order.depositAmount);
        _showOrderbook(matchingEngine, address(token1), address(token2));

        vm.prank(trader1);
        matchingEngine.marketBuy(
            address(token1),
            address(token2),
            //1400e8,
            3400000e18,
            true,
            5,
            0,
            trader1
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

    function _detMarketBuyPrice(
        uint256 mp,
        uint256 askHead,
        uint32 spread
    ) internal pure returns (uint256 price) {
        uint256 newFloor = (mp * (10000 + spread)) / 10000;
        // ask order is cleared then return new floor
        if (askHead == 0) {
            return newFloor;
        }
        // new floor is below askHead then set newFloor as ask head
        if (newFloor <= askHead) {
            return newFloor;
        }
        // if askHead is smaller than new floor, return askHead as the floor price
        return askHead;
    }

    function _detMarketSellPrice(
        uint256 mp,
        uint256 bidHead,
        uint32 spread
    ) internal pure returns (uint256 price) {
        uint256 newFloor = (mp * (10000 - spread)) / 10000;
        // bid order is cleared then return new floor
        if (bidHead == 0) {
            return newFloor;
        }
        // new floor is above bidHead then set newFloor as bid head
        if (newFloor >= bidHead) {
            return newFloor;
        }
        // if bidHead is bigger than new floor, return bidHead as the floor price
        return bidHead;
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
        uint256 mp = matchingEngine.mktPrice(address(base), address(quote));
        uint256 up = (mp * (10000 + 200)) / 10000;
        uint256 down = (mp * (10000 - 200)) / 10000;
        return (base, quote, book, mp, up, down);
    }

    // On market buy, if askHead is higher than lmp + ranged price, order is made with lmp + ranged price.
    function testMarketBuyVolatilityUp() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e11,
            1e18,
            true,
            2,
            0,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check askHead is higher than up
        assert(askHead > up);
        uint256 result = _detMarketBuyPrice(mp, askHead, 200);
        console.log("result: ", result);
        // check computed result
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5, 0, trader1);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market sell, if bidHead is lower than lmp - ranged price, order is made with lmp - ranged price.
    function testMarketSellVolatilityDown() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e6,
            1e18,
            true,
            2,
            0,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is lower than down
        assert(bidHead < down);
        uint256 result = _detMarketSellPrice(mp, bidHead, 200);
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
                0,
                trader1
            );
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
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitSell(
            address(base),
            address(quote),
            (mp * (10000 + 100)) / 10000,
            1e18,
            true,
            2,
            0,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check askHead is lower than up
        assert(askHead < up);
        uint256 result = _detMarketBuyPrice(mp, askHead, 200);
        console.log("result: ", result);
        // check computed result
        assert(result == askHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketBuy(address(base), address(quote), 1e8, true, 5, 0, trader1);
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }

    // On market sell, if bidHead is higher than lmp - ranged price, order is made with bidHead
    function testMarketSellVolatilityUp() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            (mp * (10000 - 100)) / 10000,
            1e18,
            true,
            2,
            0,
            trader1
        );
        // get pair and price info
        book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        // check bidHead is higher than down
        assert(bidHead > down);
        uint256 result = _detMarketSellPrice(mp, bidHead, 200);
        console.log("result: ", result);
        // check computed result
        assert(result == bidHead);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .marketSell(
                address(base),
                address(quote),
                1e8,
                true,
                5,
                0,
                trader1
            );
        // check make price is equal to computed result
        console.log("make price: ", makePrice);
        assert(makePrice == result);
    }
}
