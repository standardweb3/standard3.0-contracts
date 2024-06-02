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

contract GetterTest is BaseSetup {
    function testGetPrices() public {
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
            500000000,
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
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
    }

    function testGetPriceInsertion() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000000);
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
            100000000000,
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
            100200000000,
            10,
            true,
            2,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100100000000,
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
            99800000000,
            998,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            99900000000,
            999,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            99700000000,
            997,
            true,
            5,
            0,
            trader1
        );
        uint256[] memory bidPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            true,
            20
        );
        console.log("Bid prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(bidPrices[i]);
        }
        //matchingEngine.getOrders(address(token1), address(token2), true, 0, 0);
        uint256[] memory askPrices = matchingEngine.getPrices(
            address(token1),
            address(token2),
            false,
            20
        );
        console.log("Ask prices: ");
        for (uint256 i = 0; i < 3; i++) {
            console.log(askPrices[i]);
        }
    }

    function testGetOrders() public {
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
            500000000,
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
            500000000,
            10,
            true,
            5,
            0,
            trader1
        );

        console.log("Bid orders: ");
        ExchangeOrderbook.Order[] memory bidOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            500000000,
            3
        );

        for (uint256 i = 0; i < 3; i++) {
            console.log(bidOrders[i].owner, bidOrders[i].depositAmount);
        }
    }

    function testGetAskHead() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000);
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
        console.log("Ask Head:");
        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );
        console.log(book.askHead());
    }

    function testGetPairs() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000);
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

        IOrderbookFactory.Pair[] memory pairs = matchingEngine.getPairs(0, 20);
        console.log("Pairs:");
        console.log(pairs[0].base, pairs[0].quote);
    }

    function testGetPairNames() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000);
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

        IOrderbookFactory.Pair[] memory pairs = matchingEngine.getPairs(0, 20);
        console.log("Pairs:");
        console.log(pairs[0].base, pairs[0].quote);
        string[] memory names = matchingEngine.getPairNames(0, 20);
        console.log(names[0]);
    }

    function testGetOrderInsertion() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000);
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
            5,
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
            8,
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

        book = Orderbook(
            payable(orderbookFactory.getPair(address(token1), address(token2)))
        );

        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(orders[i].owner, orders[i].depositAmount);
        }
    }
}
