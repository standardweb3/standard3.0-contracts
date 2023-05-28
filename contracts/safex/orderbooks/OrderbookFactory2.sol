// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Orderbook2.sol";
import "../libraries/CloneFactory.sol";
import "../interfaces/IOrderbookFactory.sol";

contract OrderbookFactory2 is AccessControl, IOrderbookFactory {

    // Orderbooks
    address[] public allOrderbooks;
    /// Address of manager
    address public override engine;
    /// version number of impl
    uint32 public version;
    /// address of order impl
    address public impl;

    /// mapping of orderbooks based on base and quote
    mapping(address => mapping(address => address)) public orderbookByBaseQuote;
    /// mapping of base and quote asset of the orderbook
    mapping(address => IOrderbookFactory.Pair) public baseQuoteByOrderbook;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _createImpl();
    }

    /**
     * @dev Set implementation address to be used for orderbook creation, used for upgrades.
     * @param impl_ implementation contract address to get business logic
     */
    function setImpl(address impl_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        impl = impl_;
    }

    function createBook(
        address bid_,
        address ask_,
        address engine_
    ) external override returns (address orderbook) {
        require(msg.sender == engine, "OrderbookFactory: IA");
        require(
            orderbookByBaseQuote[bid_][ask_] == address(0),
            "OrderbookFactory: OB"
        );
        address proxy = CloneFactory._createClone(impl);
        IOrderbook2(proxy).initialize(
            allOrderbooksLength(),
            bid_,
            ask_,
            engine_
        );
        allOrderbooks.push(proxy);
        orderbookByBaseQuote[bid_][ask_] = proxy;
        baseQuoteByOrderbook[proxy] = Pair(bid_, ask_);
        return (proxy);
    }

    function isClone(address vault) external view returns (bool cloned) {
        cloned = CloneFactory._isClone(impl, vault);
    }

    function getBook(uint256 bookId_) external view override returns (address) {
        return allOrderbooks[bookId_];
    }

    function getBookByPair(
        address base,
        address quote
    ) external view override returns (address book) {
        return orderbookByBaseQuote[base][quote];
    }

    function getPairs(uint start, uint end) external view override returns (IOrderbookFactory.Pair[] memory) {
        IOrderbookFactory.Pair[] memory pairs = new IOrderbookFactory.Pair[](end-start);
       for(uint256 i = start; i < end; i++) {
           IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[allOrderbooks[i]];
           pairs[i] = pair;
       }
       return pairs;
    }

    function getBaseQuote(
        address orderbook
    ) external view override returns (address base, address quote) {
        IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[orderbook];
        return (pair.base, pair.quote);
    }

    function initialize(address engine_) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IA"); // Invalid Access
        engine = engine_;
    }

    function allOrderbooksLength() public view returns (uint256) {
        return allOrderbooks.length;
    }

    // Set immutable, consistent, one rule for orderbook implementation
    function _createImpl() internal {
        address addr;
        bytes memory bytecode = type(Orderbook2).creationCode;
        bytes32 salt = keccak256(abi.encodePacked("orderbook", version));
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        impl = addr;
    }
}
