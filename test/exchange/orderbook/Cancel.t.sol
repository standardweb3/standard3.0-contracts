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
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract CancelTest is BaseSetup {

    function testCancelAtPriceZeroPasses() public {
        matchingEngine.addPair(address(token1), address(token2), 300000000);
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
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
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert();
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );
    }

    function testCancelAtPriceWhateverPasses() public {
        matchingEngine.addPair(address(token1), address(token2), 300000000);
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
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
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert();
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );
    }

    // edge cases on cancelling orders
    function testCancelEdgeCase() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 700000000);
        
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            110000000,
            10,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            90000000,
            10,
            true,
            5,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            10,
            true,
            5,
            0,
            trader1
        );

        _showOrderbook(address(token1), address(token2));

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(trader1);
            matchingEngine.limitSell(
                address(token1),
                address(token2),
                110000000,
                i + 100,
                true,
                2,
                0,
                trader1
            );
        }

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            11
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // limit buy to check passing cancelled order
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            5500,
            true,
            5,
            0,
            trader1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));
    }

    function testCancelEdgeCase2() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 700000000);
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            110000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            90000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        _showOrderbook(address(token1), address(token2));

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(trader1);
            matchingEngine.limitSell(
                address(token1),
                address(token2),
                110000000,
                i + 100,
                true,
                2,
                0,
                trader1
            );
        }

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            11
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // limit buy to check passing cancelled order
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            55,
            true,
            5,
            0,
            trader1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));
    }

    function testCancelEdgeCase3() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 700000000);
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            110000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            90000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        _showOrderbook(address(token1), address(token2));

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(trader1);
            matchingEngine.limitSell(
                address(token1),
                address(token2),
                110000000,
                i + 100,
                true,
                2,
                0,
                trader1
            );
        }

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // cancel order
        vm.prank(trader1);
        //vm.expectRevert();
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            11
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // limit buy to check passing cancelled order
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            5500,
            true,
            5,
            0,
            trader1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));
    }

    function testCancelJammingOrderbook() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 1000e8);
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
            3
        );

        //_showOrderbook(matchingEngine, address(token1), address(token2));

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1400e8,
            3400000e18,
            true,
            5,
            0,
            trader1
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

    function testCancelAtHeadPrice() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 1000e8);
        
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );

        vm.prank(trader1);
        token1.approve(address(matchingEngine), 1000000000000000000e18);

        // Make buy order then cancel at head price
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            1000e18,
            true,
            5,
            0,
            trader1
        );

        (uint256 bidHead, uint256 askHead) = matchingEngine.heads(
            address(token1),
            address(token2)
        );

        console.log(bidHead, askHead);

        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            true,
            1
        );

        // Make sell orer then cancel at head price
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1001e8,
            1000e18,
            true,
            5,
            0,
            trader1
        );

        (uint256 bidHead2, uint256 askHead2) = matchingEngine.heads(
            address(token1),
            address(token2)
        );

        console.log(bidHead2, askHead2);

        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            1
        );
    }

    function testCancelOrderDeletion() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000);
        
        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0,
            trader1
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            10,
            true,
            2,
            0,
            trader1
        );

        ExchangeOrderbook.Order[] memory orders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            100000000,
            4
        );
        console.log("Ask Orders before cancel: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders[i].owner, orders[i].depositAmount);
        }

        // cancel order

        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            3
        );

        ExchangeOrderbook.Order[] memory orders2 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            100000000,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders2[i].owner, orders2[i].depositAmount);
        }
    }

    function testCancelOrders() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 700000000);

        vm.prank(booker);
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            110000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100000000,
            1000,
            true,
            2,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            90000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            1000,
            true,
            5,
            0,
            trader1
        );

        _showOrderbook(address(token1), address(token2));

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(trader1);
            matchingEngine.limitSell(
                address(token1),
                address(token2),
                110000000,
                i + 100,
                true,
                2,
                0,
                trader1
            );
        }

        address[] memory baseArray = new address[](1);
        baseArray[0] = (address(token1));

        address[] memory quoteArray = new address[](1);
        quoteArray[0] = (address(token2));
        
        bool[] memory isBidArray = new bool[](1);
        isBidArray[0] = (false);

        uint32[] memory orderIds = new uint32[](1);
        orderIds[0] = (1);


        // cancel orders
        vm.prank(trader1);
        matchingEngine.cancelOrders(
            baseArray,
            quoteArray,
            isBidArray,
            orderIds
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // cancel order
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(token1),
            address(token2),
            false,
            11
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));

        // limit buy to check passing cancelled order
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            500000000,
            55,
            true,
            5,
            0,
            trader1
        );

        // recheck orders
        _showOrderbook(address(token1), address(token2));
    }
}
