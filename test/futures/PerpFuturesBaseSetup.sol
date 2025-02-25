pragma solidity >=0.8;

import {BaseSetup} from "../exchange/OrderbookBaseSetup.sol";

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MatchingEngine} from "../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../src/exchange/orderbooks/OrderbookFactory.sol";
import {MockToken} from "../../src/mock/MockToken.sol";
import {Orderbook} from "../../src/exchange/orderbooks/Orderbook.sol";
import {WETH9} from "../../src/mock/WETH9.sol";
import {PerpFutures} from "../../src/futures/PerpFutures.sol";
import {PerpPoolFactory} from "../../src/futures/pools/PerpPoolFactory.sol";
import {PerpPool} from "../../src/futures/pools/PerpPool.sol";
import {IPerpPoolFactory} from "../../src/futures/interfaces/IPerpPoolFactory.sol";

contract PerpFuturesBaseSetup is BaseSetup {
    PerpFutures public perpFutures;
    PerpPoolFactory public perpPoolFactory;
    MockToken public stablecoin;
    address public foundation;
    address public reporter;

    function perpFuturesSetUp() public {
        users = utils.addUsers(2, users);
        foundation = users[4];
        reporter = users[5];

        stablecoin = new MockToken("Stablecoin", "STBC", 18);

        orderbookFactory = new OrderbookFactory();
        matchingEngine = new MatchingEngine();

        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(address(orderbookFactory), address(booker), address(weth));

        feeToken.mint(trader1, 10e41);
        feeToken.mint(trader2, 100000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);

        // set stablecoin price
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 100000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngine), 10000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader2);
        feeToken.approve(address(matchingEngine), 10000e18);

        // setup perp futures
        perpFutures = new PerpFutures();
        perpPoolFactory = new PerpPoolFactory();

        perpPoolFactory.initialize(address(matchingEngine), address(perpFutures));
        perpFutures.initialize(address(perpPoolFactory), address(booker), address(weth));

        // mine 1000 blocks
        utils.mineBlocks(1000);
        console.log("Block number after mining 1000 blocks: ", block.number);
    }
}
