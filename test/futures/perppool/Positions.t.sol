import {PerpFuturesBaseSetup} from "../PerpFuturesBaseSetup.sol";

contract PositionsTest is PerpFuturesBaseSetup {
    function positionsSetUp() internal {
        perpFuturesSetUp();
    }

    // test long position
    function testLong() public {
        positionsSetUp();
        perpFutures.long(address(feeToken), address(stablecoin), address(stablecoin), 1, 1);
    }

    // test short position

    // test closing position on long/short side

    // test multiple closing positions
}
