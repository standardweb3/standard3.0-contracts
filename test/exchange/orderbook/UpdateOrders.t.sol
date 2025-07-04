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
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].isLimit = true;
        updateOrderData[0].orderId = ord0Id;
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
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].orderId = ord0Id;
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
        (uint256 ord0Price, uint256 ord0Amount, uint32 ord0Id) =
            matchingEngine.limitBuy(address(token1), address(btc), 1e8, 1e8, true, 2, trader1);
        // rematch trade
        vm.prank(trader1);
        MatchingEngine.CreateOrderInput[] memory updateOrderData = new MatchingEngine.CreateOrderInput[](1);
        updateOrderData[0].base = address(token1);
        updateOrderData[0].quote = address(btc);
        updateOrderData[0].isBid = true;
        updateOrderData[0].isLimit = true;
        updateOrderData[0].orderId = ord0Id;
        updateOrderData[0].price = 1e5;
        updateOrderData[0].amount = 1e10;
        updateOrderData[0].n = 5;
        updateOrderData[0].recipient = trader1;
        matchingEngine.updateOrders(updateOrderData);
    }
}
