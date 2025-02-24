import {PointFarmSetup} from "../PointFarmSetup.sol";
import {PrizePool} from "../PointFarmSetup.sol";

contract PrizePoolTest is PointFarmSetup {
    function prizePoolSetup() internal {
        super.setUp();
        // make an event and multiplier
        vm.startPrank(trader1);
        pointFarm.createEvent(1000, 100000);
        pointFarm.setMultiplier(address(feeToken), address(stablecoin), false, 30000);
        pointFarm.setMultiplier(address(feeToken), address(stablecoin), true, 30000);
        vm.warp(10000);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        matchingEngine.limitSell(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance > 0);
        vm.stopPrank();
    }
}
