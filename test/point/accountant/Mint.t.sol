import {PointFarmSetup} from "../PointFarmSetup.sol";
import {IMatchingEngine} from "../../../src/exchange/interfaces/IMatchingEngine.sol";

contract MintTest is PointFarmSetup {
    function mintSetUp() internal {
        super.setUp();

        // make an event
        vm.startPrank(trader1);
        pointFarm.createEvent(1000, 100000);
        vm.stopPrank();
    }

    // Trading without event will not mint points
    function testTradingWithoutEventWillNotMint() public {
        vm.startPrank(trader1);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance == 0);
    }

    // Trading with event but without multiplier pair will not mint point to the user
    function testTradingWithEventWithoutMultiplierWillNotMint() public {
        mintSetUp();
        vm.startPrank(trader1);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance == 0);
    }

    function testMarketBuyAndSellWithPoints() public {
        mintSetUp();
        vm.warp(10000);
        vm.startPrank(trader1);
        base.approve(address(matchingEngine), type(uint256).max);
        usdc.approve(address(matchingEngine), type(uint256).max);

        IMatchingEngine.OrderResult memory orderResult =
            matchingEngine.marketBuy(address(base), address(usdc), 100000, true, 5, trader1, 200);

        matchingEngine.cancelOrder(address(base), address(usdc), true, orderResult.id);

        matchingEngine.marketSell(address(base), address(usdc), 1e14, true, 5, trader1, 200);
    }
}
