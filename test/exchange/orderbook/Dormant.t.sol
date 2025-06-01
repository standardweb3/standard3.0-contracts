pragma solidity >=0.8;

import {MockOrderbook} from "../../../src/exchange/orderbooks/MockOrderbook.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract DormantTest is BaseSetup {
    // if dormant order exists after circulating from the order count, the dormant order should be removed and new order should be placed
    function testDormantOrderOnBidSide() public {
        MockOrderbook mockBook = new MockOrderbook();
        mockBook.initialize(0, address(token1), address(token2), address(this));
        mockBook.setOrderCount(true, 1);
        mockBook.placeBid(address(trader1), 100000000, 100);
        mockBook.setOrderCount(true, 1);
        mockBook.placeBid(address(trader1), 100000000, 1000);
        assertEq(mockBook.removeDmt(true).depositAmount, 100);
    }
}
