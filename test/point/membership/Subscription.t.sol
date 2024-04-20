import {PointFarmSetup} from "../PointFarmSetup.sol";

contract SubscriptionTest is PointFarmSetup {
    function subcSetUp() internal {
        super.setUp();
        vm.startPrank(trader1);
        feeToken.approve(address(pointFarm), 1e40);
        pointFarm.setMembership(9, address(feeToken), 1, 1, 5);
        vm.stopPrank();
    }

    // subscription can be canceled and sends closed payment to treasury
    function testCancellationWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        pointFarm.register(9, address(feeToken));
        pointFarm.subscribe(1, address(feeToken), 100);
        pointFarm.unsubscribe(1);
    }

    // subscription can be reinititated and sends closed payment to treasury
    function testReinitiateSubscriptionWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        pointFarm.register(9, address(feeToken));
        pointFarm.subscribe(1,address(stablecoin), 10000);
        pointFarm.unsubscribe(1);
        pointFarm.subscribe(1,address(stablecoin), 10000);
    }

    // subscription can be done on only one token
    function testSubscriptionCanOnlyBeDoneOnOneToken() public {
        subcSetUp();
        vm.startPrank(trader1);
        pointFarm.register(9, address(feeToken));
        pointFarm.subscribe(1,address(stablecoin), 10000);
        vm.expectRevert();
        pointFarm.subscribe(1,address(stablecoin), 10000);
    }

    // trader point can be migrated into other ABT if one owns them all
    function testTpMigrationBetweenSameOwnerWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        pointFarm.balanceOf(address(trader1), 1);
        pointFarm.register(9, address(feeToken));
        pointFarm.subscribe(1, address(feeToken),  10000);
    }

    // subscribing with stnd shows subscribed STND amount
    function testSubSTNDIsChangedOnSTNDSubscription() public {
        subcSetUp();
        vm.startPrank(trader1);
        pointFarm.setSTND(address(feeToken));
        pointFarm.register(9, address(feeToken));
        pointFarm.subscribe(1, address(feeToken), 10000);
        uint256 subSTND = pointFarm.getSubSTND(1);
        assert(subSTND == 10000);
        vm.stopPrank();
    }
}