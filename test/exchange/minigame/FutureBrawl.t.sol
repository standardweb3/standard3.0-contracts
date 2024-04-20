import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
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
import {FutureBrawlSetup} from "../FutureBrawlSetup.sol";

contract FutureBrawlTest is FutureBrawlSetup {
    // After trading, TI and trader level can be shown

    function _trade() internal {
        Orderbook book = Orderbook(
            payable(
                orderbookFactory.getPair(address(feeToken), address(stablecoin))
            )
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            0,
            trader2
        );
        // match the order to make lmp so that accountant can report
        stablecoin.mint(address(trader1), 1000000000e18);
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngine), 1000000000e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            100000e18,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            1,
            0
        );
    }

    function _trade2() internal {
        Orderbook book = Orderbook(
            payable(
                orderbookFactory.getPair(address(feeToken), address(stablecoin))
            )
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            0,
            trader2
        );
        // match the order to make lmp so that accountant can report
        stablecoin.mint(address(trader1), 1000000000e18);
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngine), 1000000000e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            100000e18,
            true,
            5,
            0,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000000e18,
            true,
            5,
            1,
            trader1
        );
        vm.prank(trader1);
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            1,
            0
        );
        feeToken.mint(trader2, 1e40);
        vm.prank(trader2);
        feeToken.approve(address(matchingEngine), 1e40);
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            0,
            trader2
        );
    }

    function testBrawlCreate() public {
        super.futureBrawlSetUp();
        _trade();
        portal.create(address(feeToken), address(stablecoin), address(stablecoin), 10000);

    }

    function testBrawlLong() public {
       super.futureBrawlSetUp();
        _trade();
        vm.prank(trader1);
        stablecoin.approve(address(portal), 1e30);
        vm.prank(trader1);
        portal.create(address(feeToken), address(stablecoin), address(stablecoin), 10000);
        vm.prank(trader1);
        portal.long(address(feeToken), address(stablecoin), 1, address(stablecoin), 10000);
    }
}