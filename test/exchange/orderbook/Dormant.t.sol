pragma solidity >=0.8;

import {MockOrderbook} from "../../../src/exchange/mocks/MockOrderbook.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {MockBaseSetup} from "../MockOrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract DormantTest is MockBaseSetup {
    // if dormant order exists after circulating from the order count, the dormant order should be removed and new order should be placed
    function testDormantOrderOnBidSide() public {
        token1.approve(address(matchingEngine), 100000000000000000);
        token2.approve(address(matchingEngine), 100000000000000000);
        token1.mint(address(this), 1000000000000000000000000000000);
        token2.mint(address(this), 1000000000000000000000000000000);
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        address pair = matchingEngine.getPair(address(token1), address(token2));
        MockOrderbook mockBook = MockOrderbook(payable(pair));
        mockBook.setOrderCount(true, 1);
        matchingEngine.limitBuy(address(token1), address(token2), 100000000, 100, true, 1, address(trader1));
        mockBook.setOrderCount(true, 1);
        matchingEngine.limitBuy(address(token1), address(token2), 100000000, 1000, true, 1, address(trader1));
    }

    function testDormantOrderDoesNotHarmOrderbook() public {
       token1.approve(address(matchingEngine), 100000000000000000);
        token2.approve(address(matchingEngine), 100000000000000000);
        token1.mint(address(this), 1000000000000000000000000000000);
        token2.mint(address(this), 1000000000000000000000000000000);
        matchingEngine.addPair(address(token1), address(token2), 100000000, 0, address(token1));
        address pair = matchingEngine.getPair(address(token1), address(token2));
        MockOrderbook mockBook = MockOrderbook(payable(pair));
        mockBook.setOrderCount(true, 1);
        matchingEngine.limitBuy(address(token1), address(token2), 100000000, 100, true, 1, address(trader1));
        mockBook.setOrderCount(true, 1);
        matchingEngine.limitBuy(address(token1), address(token2), 100000000, 1000, true, 1, address(trader1));
    }
}
