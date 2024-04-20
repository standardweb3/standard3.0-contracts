pragma solidity >=0.8;

import {BaseSetup} from "./OrderbookBaseSetup.sol";

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {MatchingEngine} from "../../contracts/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/exchange/orderbooks/OrderbookFactory.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {Orderbook} from "../../contracts/exchange/orderbooks/Orderbook.sol";
import {WETH9} from "../../contracts/mock/WETH9.sol";
import {BrawlPortal} from "../../contracts/minigame/BrawlPortal.sol";
import {TimeBrawlFactory} from "../../contracts/minigame/brawls/time/TimeBrawlFactory.sol";

contract FutureBrawlSetup is BaseSetup {
    BrawlPortal public portal;
    TimeBrawlFactory public brawlFactory;
    MockToken public stablecoin;
    address public foundation;
    address public reporter;

    function futureBrawlSetUp() public {
        users = utils.addUsers(2, users);
        foundation = users[4];
        reporter = users[5];

        stablecoin = new MockToken("Stablecoin", "STBC");
        
        orderbookFactory = new OrderbookFactory();
        matchingEngine = new MatchingEngine();

        orderbookFactory.initialize(address(matchingEngine));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(booker),
            address(weth)
        );
        
        feeToken.mint(trader1, 10e41);
        feeToken.mint(trader2, 100000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);

        // set stablecoin price
        vm.prank(booker);
        feeToken.approve(address(matchingEngine), 100000e18);
        vm.prank(booker);
        matchingEngine.addPair(address(feeToken), address(stablecoin));
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader1);
        stablecoin.approve(address(matchingEngine), 10000e18);
        // Approve the matching engine to spend the trader's tokens
        vm.prank(trader2);
        feeToken.approve(address(matchingEngine), 10000e18);

        
        // setup brawl portal
        portal = new BrawlPortal();
        brawlFactory = new TimeBrawlFactory();

        portal.initialize(address(matchingEngine), address(brawlFactory));
        brawlFactory.initialize(address(portal));

        

        // mine 1000 blocks
        utils.mineBlocks(1000);
        console.log("Block number after mining 1000 blocks: ", block.number);
        
    }
}


