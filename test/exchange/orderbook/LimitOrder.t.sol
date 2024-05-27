pragma solidity >=0.8;

import {MockToken} from "../../../contracts/mock/MockToken.sol";
import {MockBase} from "../../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../contracts/exchange/orderbooks/Orderbook.sol";
import {IOrderbook} from "../../../contracts/exchange/interfaces/IOrderbook.sol";
import {ExchangeOrderbook} from "../../../contracts/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../contracts/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract LimitOrderTest is BaseSetup {
    function testLimitTradeWithDiffDecimals() public {
        super.setUp();
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
            0,
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
            0,
            trader2
        );
    }

    function testLimitTrade() public {
        super.setUp();
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
            0,
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
            0,
            trader2
        );
    }

    function testLimitBuyETH() public {
        super.setUp();
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
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
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testLimitSellETH() public {
        super.setUp();
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitSellETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
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
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testLimitBuyETHMakingNewBidHead() public {
        super.setUp();
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
            0,
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
            0,
            0,
            trader1
        );
    }

    // limit order is possible on out of spread range, but it is not matched
    function testLimitOrderOutOfSpreadRange() public {
        super.setUp();
        vm.prank(trader1);
        // mktprice is setup with lmp
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1e8,
            1e18,
            true,
            5,
            0,
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
        // get pair and price info
        Orderbook book = Orderbook(
            payable(matchingEngine.getPair(address(base), address(quote)))
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        uint256 lmp = IOrderbook(matchingEngine.getPair(address(base), address(quote))).lmp();
        uint256 up = (lmp * (10000 + 200)) / 10000;
        uint256 down = (lmp * (10000 - 200)) / 10000;
        return (base, quote, book, bidHead, askHead, up, down);
    }

    function _detLimitBuyPrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 lmp = IOrderbook(orderbook).lmp();
        uint256 up;
        if (lmp != 0) {
            up = (lmp * (10000 + spread)) / 10000;
            return lp >= up ? up : lp;
        } else {
            if(askHead == 0 && bidHead == 0) {
                return lp;
            }
            else if(askHead == 0 && bidHead != 0) {
                up = (bidHead * (10000 + spread)) / 10000;
                return lp >= up ? up : lp;
            }
            else if(askHead != 0 && bidHead == 0) {
                up = (askHead * (10000 + spread)) / 10000;
                return lp >= up ? up : lp;
            }
            else {
                up = (bidHead * (10000 + spread)) / 10000;
                return lp >= up ? up : lp;
            }
        }
    }

    function _detLimitSellPrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 lmp = IOrderbook(orderbook).lmp();
        uint256 down;
        if (lmp != 0) {
            down = (lmp * (10000 - spread)) / 10000;
            return lp <= down ? down : lp;
        } else {
            if(askHead == 0 && bidHead == 0) {
                return lp;
            }
            else if(askHead == 0 && bidHead != 0) {
                down = (bidHead * (10000 - spread)) / 10000;
                return lp <= down ? down : lp;
            }
            else if(askHead != 0 && bidHead == 0) {
                down = (askHead * (10000 - spread)) / 10000;
                return lp <= down ? down : lp;
            }
            else {
                down = (bidHead * (10000 - spread)) / 10000;
                return lp <= down ? down : lp;
            }
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
        uint256 result = _detLimitSellPrice(
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
                0,
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
        uint256 result = _detLimitSellPrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        assert(result == down);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitSell(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                0,
                trader1
            );
        assert(makePrice == result);
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
        uint256 result = _detLimitBuyPrice(
            address(book),
            limitPrice,
            bidHead,
            askHead,
            200
        );
        console.log("result: ", result);
        assert(result == up);
        (uint256 makePrice, uint256 _placed, uint256 _matched) = matchingEngine
            .limitBuy(
                address(base),
                address(quote),
                limitPrice,
                1e18,
                true,
                5,
                0,
                trader1
            );
        assert(makePrice == result);
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
        uint256 result = _detLimitBuyPrice(
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
                0,
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
            0,
            trader1
        );
    }
}