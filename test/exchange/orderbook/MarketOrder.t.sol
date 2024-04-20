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
}
