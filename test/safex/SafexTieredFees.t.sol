pragma solidity >=0.8;

import {BaseSetup} from "./Orderbook.t.sol";

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";

contract SAFEXFeeTierSetup is BaseSetup {
    Membership public membership;
    Treasury public treasury;
    BlockAccountant public accountant;
    SABT public sabt;
    MockToken public stablecoin;
    address public foundation;
    address public reporter;

    function setUp() public override {
        super.setUp();
        users = utils.addUsers(2, users);
        foundation = users[4];
        reporter = users[5];

        stablecoin = new MockToken("Stablecoin", "STBC");
        membership = new Membership();
        sabt = new SABT();

        accountant = new BlockAccountant(
            address(membership),
            address(matchingEngine),
            address(stablecoin),
            1
        );
        treasury = new Treasury(address(accountant), address(sabt));
        accountant.setTreasury(address(treasury));
        matchingEngine.setMembership(address(membership));
        matchingEngine.setAccountant(address(accountant));
        matchingEngine.setFeeTo(address(treasury));
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(matchingEngine)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));

        feeToken.mint(trader1, 100000e18);
        feeToken.mint(trader2, 100000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        stablecoin.approve(address(membership), 10000e18);

        // initialize  membership contract
        membership.initialize(address(sabt), foundation);
        // initialize SABT
        sabt.initialize(address(membership), address(0));
        //  set membership of meta fee lv 1
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000);

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

        // register trader1 into membership
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        membership.register(1, address(feeToken));
        assert(sabt.balanceOf(trader1, 1) == 1);

        // subscribe
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));

        // mine 1000 blocks
        utils.mineBlocks(1000);
        console.log("Block number after mining 1000 blocks: ", block.number);
        console.log("Financial block where accountant started its accounting: ", accountant.fb());

        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            10000e18,
            1000e8,
            true,
            1,
            1
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            10000e18,
            1000e8,
            true,
            1,
            1
        );
    }
}

contract FeeTierTest is SAFEXFeeTierSetup {
    // After trading, TI and trader level can be shown

    // Traders with premium accounts shows assigned level regardless of trading performance

}

contract MembershipTest is SAFEXFeeTierSetup {
    function testSetup() public {
        super.setUp();
    }

    function testRegistration() public {
        super.setUp();
        console.log(membership.getMeta(0).metaId);
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(1, address(feeToken));
    }

    function testMembershipTransfer() public {
        super.setUp();
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(1, address(feeToken));
        // transfer Membership
        vm.prank(trader1);
        sabt.transfer(trader2, 1);
    }

    function testAccountant() public {
        super.setUp();
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(1, address(feeToken));
    }

    function testAccounting() public {
        super.setUp();
        // set price in accounting price
        uint256 quoteAmount = matchingEngine.convert(
            address(feeToken),
            address(stablecoin),
            1e18,
            true
        );
        assert(quoteAmount == 1e18 * 1000);

        console.log(accountant.pointOf(1, 0));
        utils.mineBlocks(100000000000);
        vm.prank(trader1);
        treasury.exchange(address(stablecoin), 0, 1, 1);
    }
}
