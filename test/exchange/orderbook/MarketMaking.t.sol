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

contract MarketMaking is BaseSetup {
    bytes32 DEFAULT_ADMIN_ROLE = "0x0";
    bytes32 private constant MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");

    function testMarketMakingOnSellSide() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 90e8, 0, address(token1));
        vm.prank(trader1);
        matchingEngine.limitSell(address(token1), address(token2), 90e8, 100e18, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 110e8, 100e18, true, 2, trader1);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        console.log("Market price before market making: ", book.mktPrice());

        matchingEngine.grantRole(MARKET_MAKER_ROLE, address(trader1));
        vm.prank(trader1);
        // matchingEngine.adjustPrice(
        //     address(token1), address(token2), false, 70e8, 100000e18, 100000000, 100000, false, 20
        // );
        console.log("Market price after market making:", book.mktPrice());
    }

    function testMarketMakingOnBuySide() public {
        super.setUp();
        matchingEngine.addPair(address(token1), address(token2), 90e8, 0, address(token1));
        vm.prank(trader1);
        matchingEngine.limitSell(address(token1), address(token2), 90e8, 100e18, true, 2, trader1);
        vm.prank(trader1);
        matchingEngine.limitBuy(address(token1), address(token2), 110e8, 100e18, true, 2, trader1);
        book = Orderbook(payable(orderbookFactory.getPair(address(token1), address(token2))));
        console.log("Market price before market making: ", book.mktPrice());

        matchingEngine.grantRole(MARKET_MAKER_ROLE, address(trader1));
        vm.prank(trader1);
        // matchingEngine.adjustPrice(
        //     address(token1), address(token2), true, 120e8, 100000e18, 100000000, 100000, false, 20
        // );
        console.log("Market price after market making:", book.mktPrice());
    }
}
