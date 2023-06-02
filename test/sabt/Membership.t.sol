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
        membership.setMembership(0, address(feeToken), 1000, 1000, 10000, 10);
        membership.setMembership(1, address(feeToken), 1000, 1000, 10000, 10);
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
        // register trader1 into membership
        vm.prank(trader1);
        membership.register(1);
        // subscribe
        vm.prank(trader1);
        membership.subscribe(1, 10000);
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
    function testSetup() public {
        super.setUp();
    }

    function testClaimFailsWithoutMatching() public {
        super.setUp();
        vm.startPrank(trader1);
        uint256 investorTypeNFTBalance = sabt.balanceOf(trader1, 1);
        uint256 userTypeNFTBalance = sabt.balanceOf(trader1, 0);
        uint256 foundationTypeNFTBalance = sabt.balanceOf(trader1, 2);
        uint256 metaID = sabt.metaId(1);
        console.log("Meta ID: ", metaID);
        uint256 beforeBalance = stablecoin.balanceOf(trader1);
        //uint256 beforeReward = treasury.getReward(address(stablecoin), 0, 10);
        uint256 beforeClaim = treasury.getClaim(address(stablecoin), 1, 0);
        treasury.claim(address(stablecoin), 0, 1);
        treasury.claim(address(stablecoin), 0, 1);
        treasury.claim(address(stablecoin), 0, 1);
        treasury.claim(address(stablecoin), 0, 1);
        treasury.claim(address(stablecoin), 0, 1);
        treasury.claim(address(stablecoin), 0, 1);
        uint256 afterBalance = stablecoin.balanceOf(trader1);
        uint256 afterReward = treasury.getReward(address(stablecoin), 0, 10);
        uint256 afterClaim = treasury.getClaim(address(stablecoin), 1, 0);
        vm.stopPrank();
        console.log("Before balance :", beforeBalance);
        console.log("After balance :", afterBalance);
        //console.log("Before getReward :", beforeReward);
        console.log("After getReward :", afterReward);
        console.log("Before getClaim :", beforeClaim);
        console.log("After getClaim :", afterClaim);
    }
}
