import {PerpFuturesBaseSetup} from "../PerpFuturesBaseSetup.sol";

contract AddPooltTest is PerpFuturesBaseSetup {
    function addPoolSetUp() internal {
        perpFuturesSetUp();
    }

    function testAddPool() public {
        addPoolSetUp();
        // Add a pool
        perpFutures.addPool(
            address(feeToken),
            address(stablecoin),
            address(stablecoin),
            0,
            address(feeToken)
        );
    }

    function testSetListingCost() public {
        addPoolSetUp();
        // Set listing cost
        perpFutures.setListingCost(address(stablecoin), 100e18);

        // Mint some stablecoin to the lister
        stablecoin.mint(address(trader1), 1000e18);

        // Get lister's balance
        uint256 listerBalance = stablecoin.balanceOf(address(trader1));

        // list the pool with the listing cost
        vm.startPrank(trader1);
        stablecoin.approve(address(perpFutures), 100e18);
        perpFutures.addPool(
            address(feeToken),
            address(stablecoin),
            address(stablecoin),
            0,
            address(stablecoin)
        );
        vm.stopPrank();

        // Check if the lister's balance has decreased by the listing cost
        assertEq(
            stablecoin.balanceOf(address(trader1)),
            listerBalance - 100e18
        );
    }

    function testSetListingCostETH() public {
        addPoolSetUp();
        // Set listing cost
        perpFutures.setListingCost(address(weth), 1e18);

        // Mint some stablecoin to the lister
        stablecoin.mint(address(trader1), 1000e18);

        // Get lister's balance
        uint256 listerBalance = address(trader1).balance;

        // list the pool with the listing cost
        vm.startPrank(trader1);
        perpFutures.addPoolETH{value: 1e18}(
            address(feeToken),
            address(stablecoin),
            address(stablecoin),
            0
        );
        vm.stopPrank();

        // Check if the lister's balance has decreased by the listing cost
        assertEq(
            address(trader1).balance,
            listerBalance - 1e18
        );
    }
}
