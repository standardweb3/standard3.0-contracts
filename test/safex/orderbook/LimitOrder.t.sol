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

contract LimitOrderTest is BaseSetup {
    function testLimitTradeWithDiffDecimals() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1e8,
            1e8,
            true,
            2,
            0,
            trader1
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1e8,
            1e18,
            true,
            2,
            0,
            trader2
        );
    }

    function testLimitTrade() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        console.log(
            "Base/Quote Pair: ",
            matchingEngine.getPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            1e8,
            100e18,
            true,
            2,
            0,
            trader1
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            1e8,
            100e18,
            true,
            2,
            0,
            trader2
        );
    }

    function testLimitBuyETH() public {
        super.setUp();
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(weth),
            1e8,
            1e18,
            true,
            5,
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }

    function testLimitSellETH() public {
        super.setUp();
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
        vm.prank(trader1);
        matchingEngine.limitSellETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuyETH{value: 1e18}(
            address(token1),
            1e8,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        token1.approve(address(matchingEngine), 10e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(weth),
            address(token1),
            1e8,
            1e18,
            true,
            5,
            0,
            trader1
        );
        console.log("weth balance");
        console.log(trader1.balance / 1e18);
    }
}