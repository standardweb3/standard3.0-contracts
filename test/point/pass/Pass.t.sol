import {PointFarmSetup} from "../PointFarmSetup.sol";

contract MembershipTest is PointFarmSetup {
    function pSetUp() internal {
        super.setUp();
        vm.startPrank(trader1);
        feeToken.approve(address(pointFarm), 1e40);
        pointFarm.setMembership(9, address(feeToken), 1, 1, 5);
        vm.stopPrank();
    }

    // Pass Supply increases after a registration
    function testPassSupplyIncreasesAfterRegistration() public {
        pSetUp();
        vm.prank(trader1);
        pointFarm.register(9, address(feeToken));
        assert(pointFarm.getMetaSupply(9) == 1);
    }
}
