import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
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
import {SAFEXFeeTierSetup} from "../SAFEXFeeTierSetup.sol";
import {SAFEXFeeTierSetupWithoutRevShare} from "../SAFEXFeeTierSetup.sol";

contract FeeTierTest is SAFEXFeeTierSetup {
    // After trading, TI and trader level can be shown

    function _trade() internal {
        Orderbook book = Orderbook(
            payable(
                orderbookFactoryFeeTier.getPair(address(feeToken), address(stablecoin))
            )
        );
        vm.prank(trader2);
        matchingEngineFeeTier.limitSell(
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
        stablecoin.approve(address(matchingEngineFeeTier), 1000000000e18);
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            100000e18,
            true,
            5,
            1,
            trader1
        );
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(
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
        matchingEngineFeeTier.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            1,
            1
        );
    }

    function _trade2() internal {
        Orderbook book = Orderbook(
            payable(
                orderbookFactoryFeeTier.getPair(address(feeToken), address(stablecoin))
            )
        );
        vm.prank(trader2);
        matchingEngineFeeTier.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            2,
            trader2
        );
        // match the order to make lmp so that accountant can report
        stablecoin.mint(address(trader1), 1000000000e18);
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngineFeeTier), 1000000000e18);
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            100000e18,
            true,
            5,
            1,
            trader1
        );
        vm.prank(trader1);
        matchingEngineFeeTier.limitBuy(
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
        matchingEngineFeeTier.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            1,
            1
        );
        feeToken.mint(trader2, 1e40);
        vm.prank(trader2);
        feeToken.approve(address(matchingEngineFeeTier), 1e40);
        vm.prank(trader2);
        matchingEngineFeeTier.limitSell(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10000e18,
            true,
            1,
            2,
            trader2
        );
    }

    function testTraderProfileShowsTIandLvl() public {
        super.feeTierSetUp();
        _trade();
        uint256 point = accountant.pointOf(1, 0);
        uint256 ti = accountant.getTI(1);
        console.log("Trader 1 Trader Point:");
        console.log(point);
        console.log("Trader 1 TI(%):");
        console.log(ti);
    }

    // Traders with premium accounts shows assigned level regardless of trading performance
    function testTraderProfileShowsAssignedLvl() public {
        super.feeTierSetUp();
        uint256 level = accountant.levelOf(1);
        console.log("Trader 1 level:");
        console.log(level);
    }

    function testMultipleTraderProfileShowsAssignedTIandLvl() public {
        super.feeTierSetUp();
        _trade2();
        uint256 point = accountant.pointOf(1, 0);
        uint256 ti = accountant.getTI(1);
        console.log("Trader 1 Trader Point:");
        console.log(point);
        console.log("Trader 1 TI(%):");
        console.log(ti);
        uint256 point2 = accountant.pointOf(2, 0);
        uint256 ti2 = accountant.getTI(2);
        console.log("Trader 2 Trader Point:");
        console.log(point2);
        console.log("Trader 2 TI(%):");
        console.log(ti2);
    }
}
contract WithoutRevShareTest is SAFEXFeeTierSetupWithoutRevShare {
    function testSettle() public {
        super.feeTierSetUp();
    }
}