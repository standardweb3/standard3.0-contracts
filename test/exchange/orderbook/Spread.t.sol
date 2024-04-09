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
import {Treasury} from "../../../contracts/sabt/Treasury.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract OrderSpreadTest is BaseSetup {
    function testLimitOrder() public {
        super.setUp();
        vm.prank(booker);
        address base = address(token1);
        address quote = address(token2);
        matchingEngine.addPair(base, quote);
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(base, quote)
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            base,
            quote,
            3632e8,
            100e18,
            true,
            2,
            0,
            trader1
        );
        book = Orderbook(payable(matchingEngine.getPair(base, quote)));
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        vm.prank(trader2);
        matchingEngine.limitSell(
            base,
            quote,
            10000e8,
            100e18,
            true,
            2,
            0,
            trader2
        );
        console.log(matchingEngine.mktPrice(base, quote));
    }

    
    function testLimitSellSpread() public {
        super.setUp();
        vm.prank(booker);
        address base = address(token1);
        address quote = address(token2);
        matchingEngine.addPair(base, quote);
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(base, quote)
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            base,
            quote,
            3632e8,
            100e18,
            true,
            2,
            0,
            trader1
        );
        book = Orderbook(payable(matchingEngine.getPair(base, quote)));
        (uint256 bidHead, uint256 askHead) = book.heads();
        console.log(bidHead, askHead);
        vm.prank(trader2);
        matchingEngine.limitSell(
            base,
            quote,
            0e8,
            100e18,
            true,
            2,
            0,
            trader2
        );
        console.log(matchingEngine.mktPrice(base, quote));
    }
}