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

    function testMarketSellTaker() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        uint256 beforeB = base.balanceOf(trader1);
        matchingEngine.marketSell(
            address(base),
            address(quote),
            1e18,
            false,
            2,
            0,
            trader1
        );
        uint256 afterB = base.balanceOf(trader1);
        console.log("before balance: ", beforeB);
        console.log("after balance: ", afterB);
        assert(afterB > beforeB - 1e18);
    }

    function testMarketBuyTaker() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        uint256 beforeB = base.balanceOf(trader1);
        matchingEngine.marketBuy(
            address(base),
            address(quote),
            1e18,
            false,
            2,
            0,
            trader1
        );
        uint256 afterB = base.balanceOf(trader1);
        console.log("before balance: ", beforeB);
        console.log("after balance: ", afterB);
        assert(afterB > beforeB - 1e18);
    }

    function testLimitBuyTaker() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        uint256 beforeB = base.balanceOf(trader1);
        matchingEngine.limitBuy(
            address(base),
            address(quote),
            1e2,
            1e18,
            false,
            2,
            0,
            trader1
        );
        uint256 afterB = base.balanceOf(trader1);
        console.log("before balance: ", beforeB);
        console.log("after balance: ", afterB);
        assert(afterB > beforeB - 1e18);
    }

    function testLimitSellTaker() public {
        (
            MockBase base,
            MockQuote quote,
            Orderbook book,
            uint256 mp,
            uint256 up,
            uint256 down
        ) = _setupVolatilityTest();
        uint256 beforeB = base.balanceOf(trader1);
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e19,
            1e18,
            false,
            2,
            0,
            trader1
        );
        uint256 afterB = base.balanceOf(trader1);
        console.log("before balance: ", beforeB);
        console.log("after balance: ", afterB);
        assert(afterB > beforeB - 1e18);
    }


    function testCancelLimitBuySellDoesReturnOnTaker() public {
        super.setUp();
        MockBase base = new MockBase("Base Token", "BASE");
        MockQuote quote = new MockQuote("Quote Token", "QUOTE");
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
        matchingEngine.cancelOrder(address(base), address(quote), true, 1);
        uint256 beforeB = base.balanceOf(trader1);
        matchingEngine.limitSell(
            address(base),
            address(quote),
            1e8,
            1e18,
            false,
            2,
            0,
            trader1
        );
        uint256 afterB = base.balanceOf(trader1);
        console.log("before balance: ", beforeB);
        console.log("after balance: ", afterB);
        assert(afterB > beforeB - 1e18);
    }
}