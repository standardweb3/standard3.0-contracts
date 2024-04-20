import {PointFarmSetup} from "../PointFarmSetup.sol";

contract FineTest is PointFarmSetup {
    function fineSetUp() internal {
        super.setUp();
        // make an event
        vm.startPrank(trader1);
        pointFarm.createEvent(1000, 100000);
        vm.stopPrank();
    }

    // Canceling order without event will not fine in the penalty
    function testCancelingOrderWithoutEventWillNotFine() public {
        vm.startPrank(trader1);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            0
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty == 0 && pointBalance == penalty);
    }

    // Canceling order with event but without multiplier pair will not fine point to the user
    function testCancelingOrderWithEventButWithoutMultiplierWillNotFine()
        public
    {
        fineSetUp();
        vm.warp(10000);
        vm.startPrank(trader1);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            0
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty == 0 && pointBalance == penalty);
    }

    // Canceling order with event will fine in the penalty
    function testCancelingOrderWithEventWillFine() public {
        fineSetUp();
        vm.startPrank(trader1);
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            false,
            30000
        );
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            true,
            30000
        );
        vm.warp(10000);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            1
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty != 0 && penalty == pointBalance);
    }

    // Removing penalty will decrease penalty
    function testRemovingPenaltyWillDecreasePenalty() public {
        fineSetUp();
        vm.startPrank(trader1);
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            false,
            30000
        );
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            true,
            30000
        );
        vm.warp(10000);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            1
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty != 0 && penalty == pointBalance);

        // remove penalty with existing points
        pointFarm.removePenalty(297000000000000000000);
        assert(point.balanceOf(trader1) == 0);
        assert(point.penaltyOf(trader1) == 0);
    }

    // with penalty points are not given
    function testWithPenaltyPointsAreNotGiven() public {
        fineSetUp();
        vm.startPrank(trader1);
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            false,
            30000
        );
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            true,
            30000
        );
        vm.warp(10000);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            1
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty != 0 && penalty == pointBalance);

        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            1000e8,
            10e18,
            true,
            2,
            1,
            address(trader1)
        );
        pointBalance = point.balanceOf(trader1);
        penalty = point.penaltyOf(trader1);
        assert(pointBalance == 297000000000000000000);
        assert(penalty == 267300000000000000000);
    }

    // Removing penaly exceeding point balance reverts
    function testRemovingPenaltyExceedingPointBalanceReverts() public {
        fineSetUp();
        vm.startPrank(trader1);
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            false,
            30000
        );
        pointFarm.setMultiplier(
            address(feeToken),
            address(stablecoin),
            true,
            30000
        );
        vm.warp(10000);
        (uint256 makePrice, uint256 placed, uint32 id) = matchingEngine
            .limitBuy(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        matchingEngine.cancelOrder(
            address(feeToken),
            address(stablecoin),
            true,
            id,
            1
        );
        uint256 pointBalance = point.balanceOf(trader1);
        uint256 penalty = point.penaltyOf(trader1);
        assert(penalty != 0 && penalty == pointBalance);

        // remove penalty with existing points
        vm.expectRevert();
        pointFarm.removePenalty(397000000000000000000);
    }
}
