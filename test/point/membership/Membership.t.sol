import {PointFarmSetup} from "../PointFarmSetup.sol";

contract MembershipTest is PointFarmSetup {

    function mSetUp() internal {
        super.setUp();
        vm.startPrank(trader1);
        feeToken.approve(address(pointFarm), 1e40);
        pointFarm.setMembership(9, address(feeToken), 1, 1, 5);
        vm.stopPrank();
    }

    // register with fee token succeeds
    function testRegisterWithMembership() public {
        mSetUp();
        vm.prank(trader1);
        pointFarm.register(9, address(feeToken));
    }

    // register with multiple fee token succeeds
    function testRegisterWithMultipleFeeTokenSucceeds() public {
        mSetUp();
        vm.startPrank(trader1);
        pointFarm.setMembership(9, address(stablecoin), 1000, 1000, 10000);
        stablecoin.approve(address(pointFarm), 1e40);
        pointFarm.register(9, address(stablecoin));
        vm.stopPrank();
    }

    // registration is only possible with assigned token
    function testRegisterWithUnassignedTokenFails() public {
        mSetUp();
        vm.prank(trader2);
        vm.expectRevert();
        pointFarm.register(9, address(stablecoin));
    }

    // pointFarm can be transferred
    function testMembershipCanTransfer() public {
        mSetUp();
        vm.prank(trader1);
        pointFarm.register(9, address(feeToken));
        vm.prank(trader1);
        pass.transfer(trader2, 1);
    }

    // pointFarm shows the right json file for uri
    function testMembershipShowsRightJsonFileForUri() public {
        mSetUp();
        vm.prank(trader1);
        pointFarm.register(9, address(feeToken));
        vm.prank(trader1);
        string memory uri = pass.uri(1);
        assert(
            keccak256(abi.encodePacked(uri)) ==
                keccak256(
                    abi.encodePacked(
                        "https://app.standardweb3.com/api/pass/9"
                    )
                )
        );
    }
}

