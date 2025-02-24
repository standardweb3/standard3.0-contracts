import {PerpFuturesBaseSetup} from "../PerpFuturesBaseSetup.sol";

contract LeverageLimitTest is PerpFuturesBaseSetup {
    function leverageLimitSetUp() internal returns (address) {
        perpFuturesSetUp();

        return perpFutures.addPool(address(feeToken), address(stablecoin), address(stablecoin), 0, address(feeToken));
    }

    // test setting leverage limit
    function testSetLeverageLimit() public {
        address pool = leverageLimitSetUp();
        // Set leverage limit
        perpFutures.setLeverageLimit(address(feeToken), address(stablecoin), address(stablecoin), 10, 10);
        assertEq(perpFutures.getLeverage(pool, true), 10);
        assertEq(perpFutures.getLeverage(pool, false), 10);
    }
}
