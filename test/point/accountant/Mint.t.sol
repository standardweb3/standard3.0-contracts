import {PointFarmSetup} from "../PointFarmSetup.sol";

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
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance == 0);
    }

    // Trading with event but without multiplier pair will not mint point to the user
    function testTradingWithEventWithoutMultiplierWillNotMint() public {
        mintSetUp();
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
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance == 0);
    }

    // Trading with event will mint point to the user
    function testTradingWithEventWithMultiplierWillMint() public {
        mintSetUp();
        vm.startPrank(trader1);
        pointFarm.setMultiplier(address(feeToken), address(stablecoin), false, 30000);
        pointFarm.setMultiplier(address(feeToken), address(stablecoin), true, 30000);
        vm.warp(10000);
        matchingEngine
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
        matchingEngine
            .limitSell(
                address(feeToken),
                address(stablecoin),
                1000e8,
                100e18,
                true,
                2,
                1,
                address(trader1)
            );
        uint256 pointBalance = point.balanceOf(trader1);
        assert(pointBalance > 0);
    }
}