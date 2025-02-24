import {PointFarmSetup} from "../PointFarmSetup.sol";

contract FeeDiscountTest is PointFarmSetup {
    function fSetUp() internal {
        super.setUp();
        vm.startPrank(trader1);
        feeToken.approve(address(pointFarm), 1e40);
        pointFarm.setMembership(5, address(feeToken), 1e18, 1e18, 5);
        pointFarm.register(5, address(feeToken));
        pointFarm.subscribe(1, address(feeToken), 1);
        vm.stopPrank();
    }

    // subscribed membership gets fee discount
    function testSubscribingGetsExtraFeeDiscount() public {
        fSetUp();
        vm.startPrank(trader1);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        assert(pointFarm.feeOf(address(trader1), true) == 5000);
    }

    // subscribing with stnd gets extra fee discount
    function testSubscribingWithSTNDGetsExtraFeeDiscount() public {
        fSetUp();
        vm.startPrank(trader1);
        pointFarm.setSTND(address(feeToken));
        pointFarm.subscribe(1, address(feeToken), 800000);
        assert(pointFarm.feeOf(address(trader1), true) == 3750);
    }

    // unsubscribed member gets no fee discount
    function testUnsubscribeGetsNoFeeDiscount() public {
        fSetUp();
        vm.startPrank(trader1);
        pointFarm.unsubscribe(1);
        matchingEngine.limitBuy(address(feeToken), address(stablecoin), 1000e8, 100e18, true, 2, address(trader1));
        assert(pointFarm.feeOf(address(trader1), true) == 10000);
    }
}
