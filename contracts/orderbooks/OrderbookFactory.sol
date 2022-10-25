// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Orderbook.sol";
import "../libraries/CloneFactory.sol";
import "../interfaces/IOrderbookFactory.sol";


contract OrderbookFactory is AccessControl, IOrderbookFactory {
  // Orderbooks
  address[] public allOrderbooks;
  /// Address of manager
  address public override engine;
  /// version number of impl
  uint32 public version;
  /// address of order impl
  address public impl;

  struct Pair {
    address base;
    address quote;
  }      

  /// mapping of orderbooks based on base and quote
  mapping(address => mapping(address => address)) public orderbookByBaseQuote;
  /// mapping of base and quote asset of the orderbook
  mapping(address => Pair) public baseQuoteByOrderbook;

  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _createImpl();
  }

  function setImpl(address impl_) external onlyRole(DEFAULT_ADMIN_ROLE) {
    impl = impl_;
  }

  function createBook(
        address bid_,
        address ask_,
        address engine_
  ) external override returns (address orderbook) {
    require(msg.sender == engine, "OrderbookFactory: IA");
    address proxy = CloneFactory._createClone(impl);
    IOrderbook(proxy).initialize(
        bid_,
        ask_,
        engine_
    );
    allOrderbooks.push(proxy);
    orderbookByBaseQuote[bid_][ask_] = proxy;
    baseQuoteByOrderbook[proxy] = Pair(bid_, ask_);
    return (proxy);
  }

  // Set immutable, consistent, one rule for vault implementation
  function _createImpl() internal {
    address addr;
    bytes memory bytecode = type(Orderbook).creationCode;
    bytes32 salt = keccak256(abi.encodePacked("order", version));
    assembly {
      addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      if iszero(extcodesize(addr)) {
        revert(0, 0)
      }
    }
    impl = addr;
  }

  function isClone(address vault) external view returns (bool cloned) {
    cloned = CloneFactory._isClone(impl, vault);
  }

  function initialize(
    address engine_
  ) public {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "IA"); // Invalid Access
    engine = engine_;
  } 

  function getBook(uint256 bookId_) external view override returns (address) {
    return allOrderbooks[bookId_];
  }

  function getBookByPair(address base, address quote) external view override returns (address book) {
    return orderbookByBaseQuote[base][quote];
  }

  function getBaseQuote(address orderbook) external view override returns (address base, address quote) {
    Pair memory pair = baseQuoteByOrderbook[orderbook];
    return (pair.base, pair.quote);
  }

  function allOrderbooksLength() public view returns (uint256) {
    return allOrderbooks.length;
  }
}
