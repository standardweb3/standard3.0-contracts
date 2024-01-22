pragma solidity >=0.8;

import {MockToken} from "../../../contracts/mock/MockToken.sol";
import {MockBase} from "../../../contracts/mock/MockBase.sol";
import {MockQuote} from "../../../contracts/mock/MockQuote.sol";
import {MockBTC} from "../../../contracts/mock/MockBTC.sol";
import {ErrToken} from "../../../contracts/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../contracts/safex/MatchingEngine.sol";
import {OrderbookFactory} from "../../../contracts/safex/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../contracts/safex/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../contracts/safex/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../contracts/safex/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../contracts/mock/WETH9.sol";
import {Treasury} from "../../../contracts/sabt/Treasury.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";


contract PairTest is BaseSetup {
    ErrToken public err;

    function testAddPair() public {
        // create orderbook
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        matchingEngine.addPair(address(token2), address(token1));
    }

    function testAddPairWithOver18DecFails() public {
        // create orderbook
        super.setUp();

        err = new ErrToken("Error 1", "ERR1");
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(err));
        vm.expectRevert();
        matchingEngine.addPair(address(err), address(token2));
    }

    function testOrderbookAccess() public {
        super.setUp();
        vm.prank(booker);
        matchingEngine.addPair(address(token1), address(token2));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token2))
            )
        );
        vm.prank(trader1);
        vm.expectRevert();
        book.placeBid(trader1, 1e8, 2);
    }

    function testPairAlreadyAdded() public {
        super.setUp();
        vm.prank(booker);
        MockToken token3 = new MockToken("Mock3", "MOCK3");
        matchingEngine.addPair(address(token1), address(token3));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token3))
            )
        );
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(token3));
    }

    function testPairSameBaseQuote() public {
        super.setUp();
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.addPair(address(token1), address(token1));
    }

    function testPairOrderbookQuery() public {
        super.setUp();
        vm.prank(booker);
        MockToken token3 = new MockToken("Mock3", "MOCK3");
        matchingEngine.addPair(address(token1), address(token3));
        book = Orderbook(
            payable(
                orderbookFactory.getPair(address(token1), address(token3))
            )
        );
    }

    function testProxyImplCorruption() public {
        book = Orderbook(payable(orderbookFactory.impl()));
        book.initialize(
            0,
            address(weth),
            address(btc),
            address(matchingEngine)
        );
        // check if generated new pair follows impl's pair state
        MockBase mockBase2 = new MockBase("BASE2", "BASE2");
        address book2 = matchingEngine.addPair(
            address(token1),
            address(mockBase2)
        );
        (address bookBase, address bookQuote) = book.getBaseQuote();
        (address book2Base, address book2Quote) = Orderbook(payable(book2))
            .getBaseQuote();
        assert(bookBase != book2Base);
        assert(bookQuote != book2Quote);
    }
}