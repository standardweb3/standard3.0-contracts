import {PointFarmSetup} from "../PointFarmSetup.sol";

contract EventTest is PointFarmSetup {
    function eventSetUp() internal {
        super.setUp();
        // make an event
        vm.startPrank(trader1);
        pointFarm.createEvent(1000, 100000);
        vm.stopPrank();
    }

    // creating event works on first initialization
    function testCreatingEventWorksFirst() public {
        eventSetUp();
        assert(pointFarm.currentEvent() == 1);
    }

    // creating event overlapping previous event end time with next event start time errors
    function testCreatingEventOverlappingPreviousEndAndNextStartReverts() public {
        eventSetUp();
        vm.startPrank(trader1);
        vm.expectRevert();
        pointFarm.createEvent(200, 10000);
    }

    // creating event where its endTime is earlier than start time errors
    function testCreatingEventWhereEndIsEarlierThanStartReverts() public {
        eventSetUp();
        vm.startPrank(trader1);
        vm.expectRevert();
        pointFarm.createEvent(10000, 100);
    }

    // creating new event on current event will revert
    function testCreatingNewEventOnCurrentEventWillRevert() public {
        eventSetUp();
        vm.warp(8000);
        vm.expectRevert();
        pointFarm.createEvent(12000, 14000);
    }
}
