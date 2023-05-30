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
        vm.prank(trader1);
        feeToken.approve(address(membership), 10000e18);
        vm.prank(trader1);
        stablecoin.approve(address(membership), 10000e18);

        // initialize  membership contract
        membership.initialize(address(sabt), foundation);
        // initialize SABT
        sabt.initialize(address(membership), address(0));
        // set Fee in membership contract
        membership.setMembership(0, address(feeToken), 1000, 1000, 10000, 10);

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
        membership.register(0);
        assert(sabt.balanceOf(trader1, 1) == 1);

        // subscribe
        vm.prank(trader1);
        membership.subscribe(1, 10000);

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

contract MembershipTest is MembershipBaseSetup {
    function testSetup() public {
        super.setUp();
    }

    function testRegistration() public {
        super.setUp();
        console.log(membership.getMeta(0).metaId);
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(0);
    }

    function testMembershipTransfer() public {
        super.setUp();
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(0);
        // transfer Membership
        vm.prank(trader1);
        sabt.transfer(trader2, 1);
    }

    function testAccountant() public {
        super.setUp();
        // make a membership in membership contract
        vm.prank(trader1);
        membership.register(0);
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

// test cases for orderbooks
contract OrderbookTest is MembershipBaseSetup {
    function testAddPair() public {
        // create orderbook
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
    }

    function testLimitTradeWithDiffDecimals() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(btc));
        console.log(
            matchingEngine.getBookByPair(address(token1), address(btc))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(btc),
            1e8,
            1e8,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(btc),
            1e18,
            1e8,
            true,
            2,
            0
        );
    }

    function testLimitTrade() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        console.log(
            matchingEngine.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1e8,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1e8,
            true,
            2,
            0
        );
    }

    function testOrderbookAccess() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.setFee(0, 10);
        vm.prank(trader1);
        vm.expectRevert();
        book.placeBid(trader1, 1e8, 2);
    }

    function testInvalidConversion() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.setFee(0, 10);
        console.log(
            matchingEngine.getBookByPair(address(token1), address(token2))
        );
        console.log("Buy and sell with one price (Fee off)");
        vm.prank(trader1);
        uint256 trader1Token1BalanceBeforeTrade = token1.balanceOf(
            address(trader1)
        );
        uint256 trader1Token2BalanceBeforeTrade = token2.balanceOf(
            address(trader1)
        );
        uint256 trader2Token1BalanceBeforeTrade = token1.balanceOf(
            address(trader2)
        );
        uint256 trader2Token2BalanceBeforeTrade = token2.balanceOf(
            address(trader2)
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        uint256 trader1Token1BalanceAfterTrade = token1.balanceOf(
            address(trader1)
        );
        uint256 trader1Token2BalanceAfterTrade = token2.balanceOf(
            address(trader1)
        );
        uint256 trader2Token1BalanceAfterTrade = token1.balanceOf(
            address(trader2)
        );
        uint256 trader2Token2BalanceAfterTrade = token2.balanceOf(
            address(trader2)
        );
        uint256 diffToken1Trader1 = trader1Token1BalanceAfterTrade -
            trader1Token1BalanceBeforeTrade;
        uint256 diffToken2Trader1 = trader1Token2BalanceBeforeTrade -
            trader1Token2BalanceAfterTrade;
        uint256 diffToken1Trader2 = trader2Token1BalanceBeforeTrade -
            trader2Token1BalanceAfterTrade;
        uint256 diffToken2Trader2 = trader2Token2BalanceAfterTrade -
            trader2Token2BalanceBeforeTrade;
        console.log("trader1 received Token1: ", diffToken1Trader1);
        console.log("trader1 spent Token2:    ", diffToken2Trader1);
        console.log("trader2 spent Token1:    ", diffToken1Trader2);
        console.log("trader1 received Token2: ", diffToken2Trader2);
        console.log(
            "------------------------------------------------------------------------"
        );
        console.log("Sell and buy with one price (Fee off)");
        trader1Token1BalanceBeforeTrade = token1.balanceOf(address(trader1));
        trader1Token2BalanceBeforeTrade = token2.balanceOf(address(trader1));
        trader2Token1BalanceBeforeTrade = token1.balanceOf(address(trader2));
        trader2Token2BalanceBeforeTrade = token2.balanceOf(address(trader2));
        vm.prank(trader2);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            1,
            true,
            2,
            0
        );
        trader1Token1BalanceAfterTrade = token1.balanceOf(address(trader1));
        trader1Token2BalanceAfterTrade = token2.balanceOf(address(trader1));
        trader2Token1BalanceAfterTrade = token1.balanceOf(address(trader2));
        trader2Token2BalanceAfterTrade = token2.balanceOf(address(trader2));
        diffToken1Trader1 =
            trader1Token1BalanceAfterTrade -
            trader1Token1BalanceBeforeTrade;
        diffToken2Trader1 =
            trader1Token2BalanceBeforeTrade -
            trader1Token2BalanceAfterTrade;
        diffToken1Trader2 =
            trader2Token1BalanceBeforeTrade -
            trader2Token1BalanceAfterTrade;
        diffToken2Trader2 =
            trader2Token2BalanceAfterTrade -
            trader2Token2BalanceBeforeTrade;
        console.log("trader1 received Token1: ", diffToken1Trader1);
        console.log("trader1 spent Token2:    ", diffToken2Trader1);
        console.log("trader2 spent Token1:    ", diffToken1Trader2);
        console.log("trader1 received Token2: ", diffToken2Trader2);
    }

    function testManipulateMarketPrice() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            100e18,
            90e8,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            100e18,
            110e8,
            true,
            2,
            0
        );
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        console.log("Market price before manipulation: ", book.mktPrice());
        vm.prank(attacker);
        //book.placeBid(address(trader1), 1e7, 100e18);
        //vm.prank(attacker);
        //book.placeAsk(address(trader1), 1e8, 100e18);
        console.log("Market price after manipulation:", book.mktPrice());
    }

    function testNewOrderLinkedListOutOfGas() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);

        // placeBid or placeAsk two of them is using the _insert function it will revert
        // because the program will enter the (price < last) statement
        // and eventually, it will cause an infinite loop.
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            2,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitBuy(
            address(token1),
            address(token2),
            10,
            1,
            true,
            2,
            0
        );
    }

    function testNewOrderLinkedListOutOfGasPlaceBid() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        // We can create the same example with placeBid function
        // This time the program will enter the while (price > last && last != 0) statement
        // and it will cause an infinite loop.
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            2,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            6,
            true,
            2,
            0
        );
    }

    function testNewOrderOrderbookOutOfGas() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            orderbookFactory.getBookByPair(address(token1), address(token2))
        );
        vm.prank(trader1);
        // placeBid or placeAsk two of them is using the _insertId function it will revert
        // because the program will enter the "if (amount > self.orders[head].depositAmount)."
        // statement, and eventually, it will cause an infinite loop.
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            5,
            true,
            2,
            0
        );
        vm.prank(trader1);
        //vm.expectRevert("OutOfGas");
        matchingEngine.limitSell(
            address(token1),
            address(token2),
            10,
            1,
            true,
            2,
            0
        );
    }
}
