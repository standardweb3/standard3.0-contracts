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

interface IMatchingEngine {
    struct UpdateOrder {
        address base;
        address quote;
        bool isBid;
        uint32 orderId;
        uint256 price;
        uint256 amount;
        uint32 n;
        address recipient;
    }
}

contract LimitOrderTest is BaseSetup {
    // rematch order so that amount is changed from the exact order
    function testRematchOrderAmountIncrease() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log("Base/Quote Pair: ", matchingEngine.getPair(address(token1), address(btc)));
        vm.prank(trader1);
        MatchingEngine.OrderResult memory ord0Result =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].isLimit = true;
        updateOrderData[0].orderId = ord0Result.id;
        updateOrderData[0].price = 1e8;
        updateOrderData[0].amount = 1e10;
        updateOrderData[0].n = 2;
        updateOrderData[0].recipient = trader1;
        matchingEngine.updateOrders(updateOrderData);
    }

    function testRematchOrderAmountDecrease() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log("Base/Quote Pair: ", matchingEngine.getPair(address(token1), address(btc)));
        vm.prank(trader1);
        MatchingEngine.OrderResult memory ord0Result =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].orderId = ord0Result.id;
        updateOrderData[0].price = 1e8;
        updateOrderData[0].amount = 1e5;
        updateOrderData[0].n = 5;
        updateOrderData[0].recipient = trader1;
        matchingEngine.updateOrders(updateOrderData);
    }

    // rematch order so that price is changed from the exact order
    function testRematchOrderPrice() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        console.log("Base/Quote Pair: ", matchingEngine.getPair(address(token1), address(btc)));
        vm.prank(trader1);
        MatchingEngine.OrderResult memory ord0Result =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].isLimit = true;
        updateOrderData[0].orderId = ord0Result.id;
        updateOrderData[0].price = 1e5;
        updateOrderData[0].amount = 1e10;
        updateOrderData[0].n = 5;
        updateOrderData[0].recipient = trader1;
        matchingEngine.updateOrders(updateOrderData);
    }

    function testCreateOrders() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(btc), 1e8, 0, address(token1));
        matchingEngine.addPair(address(weth), address(btc), 1e8, 0, address(token1));
        matchingEngine.addPair(address(btc), address(weth), 1e8, 0, address(token1));
        console.log("Base/Quote Pair: ", matchingEngine.getPair(address(token1), address(btc)));
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory openOrders = new MatchingEngine.CreateOrderInput[](6);
        // Order 1: limit Buy
        openOrders[0].base = address(token1);
        openOrders[0].quote = address(btc);
        openOrders[0].isBid = true;
        openOrders[0].isLimit = true;
        openOrders[0].price = 1e5;
        openOrders[0].amount = 1e18;
        openOrders[0].n = 5;
        openOrders[0].recipient = trader1;
        // Order 2: limit Sell
        openOrders[1].base = address(token1);
        openOrders[1].quote = address(btc);
        openOrders[1].isBid = false;
        openOrders[1].isLimit = true;
        openOrders[1].price = 1e5;
        openOrders[1].amount = 1e18;
        openOrders[1].n = 5;
        openOrders[1].recipient = trader1;
        // Order 3: market Buy
        openOrders[2].base = address(token1);
        openOrders[2].quote = address(btc);
        openOrders[2].isBid = true;
        openOrders[2].isLimit = false;
        openOrders[2].price = 1e5;
        openOrders[2].amount = 1e18;
        openOrders[2].n = 5;
        openOrders[2].recipient = trader1;
        // Order 4: market Sell
        openOrders[3].base = address(token1);
        openOrders[3].quote = address(btc);
        openOrders[3].isBid = false;
        openOrders[3].isLimit = false; 
        openOrders[3].price = 1e5;
        openOrders[3].amount = 1e18;
        openOrders[3].n = 5;
        openOrders[3].recipient = trader1;
        // Order 5: limit Buy ETH
        openOrders[4].base = address(btc);
        openOrders[4].quote = address(weth);
        openOrders[4].isBid = true;
        openOrders[4].isLimit = true;
        openOrders[4].price = 1e5;
        openOrders[4].amount = 1e18;
        openOrders[4].n = 5;
        // Order 6: limit Sell ETH
        openOrders[5].base = address(weth);
        openOrders[5].quote = address(btc);
        openOrders[5].isBid = false;
        openOrders[5].isLimit = true;
        openOrders[5].price = 1e5;
        openOrders[5].amount = 1e18;

        // now create open orders
        MatchingEngine.OrderResult[] memory orderResults = matchingEngine.createOrders{value: 2e18}(openOrders);
        for (uint256 i = 0; i < orderResults.length; i++) {
            console.log("Order Result: ", orderResults[i].makePrice, orderResults[i].placed, orderResults[i].id);
        }
    }
}
