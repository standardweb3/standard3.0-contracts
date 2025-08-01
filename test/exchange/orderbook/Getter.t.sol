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

contract GetterTest is BaseSetup {
    function testGetPrices() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        vm.prank(booker);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(address(token1), address(token2), 500000000, 10, true, 2, trader1);

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 10, true, 2, trader1);

        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 90000000, 10, true, 5, trader1);

        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 500000000, 10, true, 5, trader1);
    }

    function testGetPriceInsertion() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000000, 0, address(token1));
        vm.prank(booker);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(address(token1), address(token2), 100000000000, 10, true, 2, trader1);
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100200000000, 10, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitSell(address(token1), address(token2), 100100000000, 10, true, 5, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 99800000000, 998, true, 5, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 99900000000, 999, true, 5, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 99700000000, 997, true, 5, trader1);
    }

    function testGetOrders() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        vm.prank(booker);

        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(address(token1), address(token2), 500000000, 10, true, 2, trader1);
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 10, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 500000000, 10, true, 5, trader1);
    }

    function testGetAskHead() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(address(token1), address(token2), 500000000, 10, true, 2, trader1);
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 10, true, 2, trader1);
        console.log("Ask Head:");
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        console.log(book.askHead());
    }

    function testGetOrderInsertion() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 10, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 10, true, 2, trader1);
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 5, true, 2, trader1);
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(address(token1), address(token2), 100000000, 8, true, 2, trader1);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
    }
}
