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

contract OutOfOrderbookTest is BaseSetup {
    function testRemoveHeadOnMatch() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token2))
            )
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            2,
            0,
            trader1
        );
        console.log("Ask Orders: ");
        ExchangeOrderbook.Order[] memory askOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders0[i].owner, askOrders0[i].depositAmount);
        }
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            false,
            2,
            0,
            trader1
        );
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        console.log("Ask Orders: ");
        ExchangeOrderbook.Order[] memory askOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders[i].owner, askOrders[i].depositAmount);
        }
        console.log(book.isEmpty(false, 1000e8));
        //console.log(book.checkRequired());
        vm.prank(trader1);

        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            10000e18,
            true,
            2,
            0,
            trader1
        );
    }

    function testMatchOrders() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token2))
            )
        );
        vm.prank(trader2);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1000e8,
            3000e18,
            true,
            2,
            0,
            trader2
        );

        ExchangeOrderbook.Order[] memory bidOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            true,
            1000e8,
            4
        );
        console.log("Bid Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidOrders0[i].owner, bidOrders0[i].depositAmount);
        }

        ExchangeOrderbook.Order[] memory askOrders0 = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders0[i].owner, askOrders0[i].depositAmount);
        }

        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            1e18,
            true,
            2,
            0,
            trader1
        );

        ExchangeOrderbook.Order[] memory bidOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            true,
            1000e8,
            4
        );
        console.log("Bid Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(bidOrders[i].owner, bidOrders[i].depositAmount);
        }

        ExchangeOrderbook.Order[] memory askOrders = matchingEngine.getOrders(
            address(token1),
            address(token2),
            false,
            1000e8,
            4
        );
        console.log("Ask Orders: ");
        for (uint256 i = 0; i < 4; i++) {
            console.log(askOrders[i].owner, askOrders[i].depositAmount);
        }
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);

        vm.prank(trader2);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1000e8,
            1e18,
            true,
            2,
            0,
            trader2
        );
    }

    function testAmountIsZero() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token2))
            )
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
    }
}