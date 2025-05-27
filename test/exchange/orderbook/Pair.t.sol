pragma solidity >=0.8;

import {MockToken} from "../../../src/mock/MockToken.sol";
import {MockBase} from "../../../src/mock/MockBase.sol";
import {MockQuote} from "../../../src/mock/MockQuote.sol";
import {MockBTC} from "../../../src/mock/MockBTC.sol";
import {ErrToken} from "../../../src/mock/MockTokenOver18Decimals.sol";
import {Utils} from "../../utils/Utils.sol";
import {MatchingEngine} from "../../../src/exchange/MatchingEngine.sol";
import {OrderbookFactory} from "../../../src/exchange/orderbooks/OrderbookFactory.sol";
import {Orderbook} from "../../../src/exchange/orderbooks/Orderbook.sol";
import {ExchangeOrderbook} from "../../../src/exchange/libraries/ExchangeOrderbook.sol";
import {IOrderbookFactory} from "../../../src/exchange/interfaces/IOrderbookFactory.sol";
import {WETH9} from "../../../src/mock/WETH9.sol";
import {BaseSetup} from "../OrderbookBaseSetup.sol";
import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

contract PairTest is BaseSetup {
    function testAddPairEmitsListedTerminalFromAdmin() public {
        uint32[] memory listed = new uint32[](3);
        listed[0] = 1;
        listed[1] = 2;
        listed[2] = 3;
        matchingEngine.addPair(
            address(token1),
            address(token2),
            300000000,
            0,
            address(token1)
        );
    }

    function testAddPairOnlyAllowedByAdmin() public {
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.addPair(
            address(token1),
            address(token2),
            300000000,
            0,
            address(token1)
        );
    }

    function testUpdatePairOnlyAllowedByAdmin() public {
        vm.prank(booker);
        vm.expectRevert();
        matchingEngine.updatePair(address(token1), address(token2), 300000000, 0);
    }

    function testUpdatePairNotAllowedWithZeroSupportedTerminals() public {
        vm.expectRevert();
        matchingEngine.updatePair(address(token1), address(token2), 300000000, 0);
    }

    function testUpdatePairEmitsTerminalsBeforeAndAfter() public {
        uint32[] memory listed = new uint32[](3);
        listed[0] = 1;
        listed[1] = 2;
        listed[2] = 3;
        matchingEngine.addPair(address(token1), address(token2), 300000000, 0, address(token1));

        uint32[] memory listed2 = new uint32[](2);
        listed2[0] = 2;
        listed2[1] = 3;

        matchingEngine.updatePair(address(token1), address(token2), 300000000, 0);
    }
}
