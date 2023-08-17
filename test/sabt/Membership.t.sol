pragma solidity >=0.8;
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {Utils} from "../utils/Utils.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {MatchingEngine} from "../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {TreasuryLib} from "../../contracts/sabt/libraries/TreasuryLib.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";

contract MembershipBaseSetup is Test {
    Membership public membership;
    Treasury public treasury;
    BlockAccountant public accountant;
    SABT public sabt;
    MockToken public stablecoin;
    MockToken public feeToken;
    address public foundation;
    address public reporter;
    OrderbookFactory orderbookFactory;

    Utils public utils;
    MatchingEngine public matchingEngine;
    address payable[] public users;
    address public trader1;
    address public trader2;
    address public booker;
    address public attacker;

    function setUp() public {
        utils = new Utils();
        users = utils.addUsers(6, users);
        trader1 = users[0];
        vm.label(trader1, "Trader 1");
        trader2 = users[1];
        vm.label(trader2, "Trader 2");
        booker = users[2];
        vm.label(booker, "Booker");
        attacker = users[3];
        vm.label(attacker, "Attacker");
        foundation = users[4];
        vm.label(foundation, "Foundation");
        reporter = users[5];
        vm.label(reporter, "Reporter");
        feeToken = new MockToken("FeeToken", "FEE");
        stablecoin = new MockToken("Stablecoin", "STBC");
        membership = new Membership();
        sabt = new SABT();
        accountant = new BlockAccountant();
        treasury = new Treasury();
        matchingEngine = new MatchingEngine();
        orderbookFactory = new OrderbookFactory();
        membership.initialize(address(sabt), foundation);
        sabt.initialize(address(membership));
        treasury.initialize(address(accountant), address(sabt));
        matchingEngine.initialize(
            address(orderbookFactory),
            address(membership),
            address(accountant),
            address(treasury)
        );
        orderbookFactory.initialize(address(matchingEngine));
        accountant.initialize(
            address(membership), address(matchingEngine), address(stablecoin), 1
        );
        accountant.grantRole(
            accountant.REPORTER_ROLE(),
            address(matchingEngine)
        );
        treasury.grantRole(treasury.REPORTER_ROLE(), address(matchingEngine));
        
        feeToken.mint(trader1, 100000000e18);
        feeToken.mint(trader2, 10000e18);
        feeToken.mint(booker, 100000e18);
        stablecoin.mint(trader1, 10000e18);
        stablecoin.mint(trader2, 10000e18);
        stablecoin.mint(address(treasury), 10000e18);
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        stablecoin.approve(address(membership), 10000e18);
        // initialize membership contract
        treasury.setClaim(1, 100);
        // initialize SABT
        // set Fee in membership contract
        membership.setMembership(9, address(feeToken), 1000, 1000, 10000);
        membership.setMembership(10, address(feeToken), 1000, 1000, 10000);
        // membership.setMembership(2, address(feeToken), 1000, 1000, 10000, 10);
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
        membership.grantRole(membership.DEFAULT_ADMIN_ROLE(), trader1);
        // register trader1 to investor
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        // subscribe
        vm.prank(trader1);
        feeToken.approve(address(membership), 1e25);
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        // mine 1000 blocks
        utils.mineBlocks(1000);
        // make a price in matching engine where 1 feeToken = 1000 stablecoin with buy and sell order
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(feeToken),
            address(stablecoin),
            10000e8,
            1000e10,
            true,
            1,
            1
        );
        // match the order to make lmp so that accountant can report
        vm.prank(trader1);
        feeToken.approve(address(matchingEngine), 10000e18);
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(feeToken),
            address(stablecoin),
            10000e8,
            1000e10,
            true,
            1,
            1
        );
    }
}

contract MembershipTest is MembershipBaseSetup {

    function mSetUp() internal {
        super.setUp();
        vm.prank(trader1);
        feeToken.approve(address(membership), 1e40);
    }

    // register with fee token succeeds
    function testRegisterWithMembership() public {
        mSetUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
    }

    // register with multiple fee token succeeds
    function testRegisterWithMultipleFeeTokenSucceeds() public {
        mSetUp();
        membership.setMembership(9, address(feeToken), 1000, 1000, 10000);
        vm.startPrank(trader1);
        feeToken.approve(address(membership), 1e40);
        membership.register(9, address(feeToken));
    }

    // registration is only possible with assigned token
    function testRegisterWithUnassignedTokenFails() public {
        mSetUp();
        vm.prank(trader1);
        vm.expectRevert();
        membership.register(9, address(stablecoin));
    }

    // membership can be transferred
    function testMembershipCanTransfer() public {
        mSetUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        sabt.transfer(trader2, 1);
    }

    // membership shows the right json file for uri
    function testMembershipShowsRightJsonFileForUri() public {
        mSetUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        string memory uri = sabt.uri(1);
        assert(
            keccak256(abi.encodePacked(uri)) ==
                keccak256(
                    abi.encodePacked(
                        "https://raw.githubusercontent.com/standardweb3/nft-arts/main/nfts/sabt/9"
                    )
                )
        );
    }
}

contract SubscriptionTest is MembershipBaseSetup {
    function subcSetUp() internal {
        super.setUp();
        vm.prank(trader1);
        feeToken.approve(address(membership), 1e40);
    }

    // subscription can be canceled and sends closed payment to treasury
    function testCancellationWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        membership.register(9, address(feeToken));
        membership.subscribe(1, 100, address(feeToken));
        membership.unsubscribe(1);
    }

    // subscription can be reinititated and sends closed payment to treasury
    function testReinitiateSubscriptionWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        membership.register(9, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        membership.unsubscribe(1);
        membership.subscribe(1, 10000, address(feeToken));
    }

    // subscription can be done on only one token
    function testSubscriptionCanOnlyBeDoneOnOneToken() public {
        subcSetUp();
        vm.startPrank(trader1);
        membership.register(9, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        vm.expectRevert();
        membership.subscribe(1, 10000, address(feeToken));
    }

    // trader point can be migrated into other ABT if one owns them all
    function testTpMigrationBetweenSameOwnerWorks() public {
        subcSetUp();
        vm.startPrank(trader1);
        membership.balanceOf(address(trader1), 1);
        membership.register(9, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        accountant.migrate(1, 2, 0, 100);
    }

    // subscribing with stnd shows subscribed STND amount
    function testSubSTNDIsChangedOnSTNDSubscription() public {
        subcSetUp();
        membership.setSTND(address(feeToken));
        vm.startPrank(trader1);
        membership.register(9, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        uint256 subSTND = membership.getSubSTND(1);
        assert(subSTND == 10000000);
    }
}

contract MembershipTresuryTest is MembershipBaseSetup {
    function tSetUp() internal {
        super.setUp();
        vm.prank(trader1);
        feeToken.approve(address(membership), 1e40);
    }

    // members can exchange TP with token reward only after an era passes
    function testExchangeWorksOnlyIfEraPasses() public {
        tSetUp();
        vm.startPrank(trader1);
        vm.expectRevert(
            abi.encodeWithSelector(TreasuryLib.EraNotPassed.selector, 1, 0)
        );
        treasury.exchange(address(feeToken), 1, 1, 1000);
    }

    // early adoptors can settle share of revenue from foundation
    function testClaimRevenueWorksWorksForOnlyEarlyAdoptors() public {
        tSetUp();
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000);
        vm.startPrank(trader1);
        membership.register(1, address(feeToken));
        membership.register(10, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        membership.unsubscribe(1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.expectRevert(
            abi.encodeWithSelector(TreasuryLib.InvalidMetaId.selector, 9, 2, 1)
        );
        treasury.claim(address(feeToken), 0, 2);
        vm.expectRevert(
            abi.encodeWithSelector(TreasuryLib.InvalidMetaId.selector, 9, 3, 10)
        );
        treasury.claim(address(feeToken), 0, 3);
    }

    // Only foundation can settle share of revenue on treasury
    function testSettleRevenueWorksForOnlyFoundation() public {
        tSetUp();
        vm.startPrank(trader1);
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000);
        membership.register(1, address(feeToken));
        membership.register(9, address(feeToken));
        membership.subscribe(1, 10000, address(feeToken));
        vm.expectRevert(
            abi.encodeWithSelector(TreasuryLib.InvalidMetaId.selector, 10, 2, 1)
        );
        treasury.settle(address(feeToken), 0, 2);
        vm.expectRevert(
            abi.encodeWithSelector(TreasuryLib.InvalidMetaId.selector, 10, 3, 9)
        );
        treasury.settle(address(feeToken), 0, 3);
    }
}
