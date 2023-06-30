pragma solidity >=0.8;
import {BaseSetup} from "../safex/Orderbook.t.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";
import {SABT} from "../../contracts/sabt/SABT.sol";
import {BlockAccountant} from "../../contracts/sabt/BlockAccountant.sol";
import {Membership} from "../../contracts/sabt/Membership.sol";
import {Treasury} from "../../contracts/sabt/Treasury.sol";
import {MockToken} from "../../contracts/mock/MockToken.sol";
import {Orderbook} from "../../contracts/safex/orderbooks/Orderbook.sol";

contract MembershipBaseSetup is BaseSetup {
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
        feeToken.mint(trader1, 10000e18);
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
        membership.initialize(address(sabt), foundation);
        treasury.setClaim(1, 100);
        // initialize SABT
        sabt.initialize(address(membership), address(0));
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
        membership.subscribe(1, 10000, address(feeToken));
        // mine 1000 blocks
        utils.mineBlocks(1000);
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
    }
}

contract MembershipTest is MembershipBaseSetup {
    // register with fee token succeeds
    function registerWithMembership() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
    }

    // register with multiple fee token succeeds
    function registerWithMultipleFeeTokenSucceeds() public {
        super.setUp();
        membership.setMembership(9, address(token1), 1000, 1000, 10000);
        vm.prank(trader1);
        membership.register(9, address(token1));
    }

    // registration is only possible with assigned token
    function registerWithUnassignedTokenFails() public {
        super.setUp();
        vm.prank(trader1);
        vm.expectRevert();
        membership.register(9, address(token2));
    }

    // membership can be transferred
    function membershipCanTransfer() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.transfer(trader2, 9);
    }

    // membership shows the right json file for uri
    function membershipShowsRightJsonFileForUri() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        string uri = membership.uri(1);
        assert(keccak256(abi.encodePacked(uri)) == keccak256(abi.encodePacked("https://raw.githubusercontent.com/standardweb3/nft-arts/main/nfts/sabt/1")));
    }
}

contract SubscriptionTest is MembershipBaseSetup {
    // subscription can be canceled and sends closed payment to treasury
    function cancellationWorks() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        membership.cancel(1);
    }

    // subscription can be reinititated and sends closed payment to treasury
    function reinitiateSubscriptionWorks() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        membership.cancel(1);
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
    }

    // subscription can be done on only one token
    function subscriptionCanOnlyBeDoneOnOneToken() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        vm.expectRevert();
        membership.subscribe(1, 10000, address(token1));
    }

    // trader point can be migrated into other ABT if one owns them all
    function TPMigrationBetweenSameOwnerWorks() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        membership.migrate(1, 2);
    }

    // subscribing with stnd shows subscribed STND amount
    function subSTNDIsChangedOnSTNDSubscription() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        uint256 subSTND = membership.subSTND(1);
        assert(subSTND == 10000);
    }
}

contract MembershipTresuryTest is MembershipBaseSetup {
    // members can exchange TP with token reward only after an era passes
    function exchangeWorksOnlyIfEraPasses() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        vm.expectRevert();
        membership.exchange(1, 10000);
    }

    // early adoptors can settle share of revenue from foundation
    function claimRevenueWorksWorksForOnlyEarlyAdoptors() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(1, address(feeToken));
        vm.prank(trader1);
        membership.register(10, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        membership.cancel(1);
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        vm.expectRevert();
        treasury.claim(2, 10000);
        vm.expectRevert();
        treasury.claim(3, 10000);
    }

    // Only foundation can settle share of revenue on treasury
    function settleRevenueWorksForOnlyFoundation() public {
        super.setUp();
        vm.prank(trader1);
        membership.register(1, address(feeToken));
        vm.prank(trader1);
        membership.register(9, address(feeToken));
        vm.prank(trader1);
        membership.subscribe(1, 10000, address(feeToken));
        vm.prank(trader1);
        vm.expectRevert();
        treasury.settle(2, 10000);
        vm.prank(trader1);
        vm.expectRevert();
        treasury.settle(3, 10000);
    }
}

