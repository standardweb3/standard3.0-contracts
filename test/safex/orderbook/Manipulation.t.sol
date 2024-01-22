pragma solidity >=0.8;

import {MockToken} from "../../../contracts/mock/MockToken.sol";
import {MockBase} from "../../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../contracts/safex/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../contracts/safex/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../contracts/safex/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {Treasury} from "../../../contracts/sabt/Treasury.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract ManipulationTest is BaseSetup {
    function testManipulateMarketPrice() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            90e8,
            100e18,
            true,
            2,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            110e8,
            100e18,
            true,
            2,
            0,
            trader1
        );
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token2))
            )
        );
        console.log("Market price before manipulation: ", book.mktPrice());
        vm.prank(attacker);
        //book.placeBid(address(trader1), 1e7, 100e18);
        //vm.prank(attacker);
        //book.placeAsk(address(trader1), 1e8, 100e18);
        console.log("Market price after manipulation:", book.mktPrice());
    }
}