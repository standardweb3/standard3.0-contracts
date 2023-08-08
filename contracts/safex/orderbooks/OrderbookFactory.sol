// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Orderbook, IOrderbook} from "./Orderbook.sol";
import {CloneFactory} from "../libraries/CloneFactory.sol";
import {IOrderbookFactory} from "../interfaces/IOrderbookFactory.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20 {
    function symbol() external view returns (string memory);
}

contract OrderbookFactory is AccessControl, IOrderbookFactory, Initializable {
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

    error InvalidRole(bytes32 role, address sender);

    error InvalidAccess(address sender, address allowed);
    error PairAlreadyExists(address base, address quote);

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
        address ask_
    ) external override returns (address orderbook) {
        if (msg.sender != engine) {
            revert InvalidAccess(msg.sender, engine);
        }
        if (orderbookByBaseQuote[bid_][ask_] != address(0)) {
            revert PairAlreadyExists(bid_, ask_);
        }
        address proxy = CloneFactory._createClone(impl);
        IOrderbook(proxy).initialize(allOrderbooksLength(), bid_, ask_, engine);
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

    function getPairs(
        uint256 start,
        uint256 end
    ) public view override returns (IOrderbookFactory.Pair[] memory) {
        uint256 last = end > allOrderbooks.length ? allOrderbooks.length : end;
        IOrderbookFactory.Pair[] memory pairs = new IOrderbookFactory.Pair[](
            last - start
        );
        for (uint256 i = start; i < last; i++) {
            IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[
                allOrderbooks[i]
            ];
            pairs[i] = pair;
        }
        return pairs;
    }

    function getPairsWithIds(
        uint256[] memory ids
    ) public view override returns (IOrderbookFactory.Pair[] memory pairs) {
        pairs = new IOrderbookFactory.Pair[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[
                allOrderbooks[ids[i]]
            ];
            pairs[i] = pair;
        }
        return pairs;
    }

    function getPairNames(
        uint256 start,
        uint256 end
    ) external view override returns (string[] memory names) {
        IOrderbookFactory.Pair[] memory pairs = getPairs(start, end);
        names = new string[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            string memory baseName = IERC20(pairs[i].base).symbol();
            string memory quoteName = IERC20(pairs[i].quote).symbol();
            names[i] = string(abi.encodePacked(baseName, "/", quoteName));
        }
        return names;
    }

    function getPairNamesWithIds(
        uint256[] memory ids
    ) external view override returns (string[] memory names) {
        names = new string[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[
                allOrderbooks[ids[i]]
            ];
            string memory baseName = IERC20(pair.base).symbol();
            string memory quoteName = IERC20(pair.quote).symbol();
            names[i] = string(abi.encodePacked(baseName, "/", quoteName));
        }
        return names;
    }

    function getBaseQuote(
        address orderbook
    ) external view override returns (address base, address quote) {
        IOrderbookFactory.Pair memory pair = baseQuoteByOrderbook[orderbook];
        return (pair.base, pair.quote);
    }

    /**
     * @dev Initialize orderbook factory contract with engine address, reinitialize if engine is reset.
     * @param engine_ The address of the engine contract
     */
    function initialize(address engine_) public initializer {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            // Invalid Access
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        engine = engine_;
    }

    function allOrderbooksLength() public view returns (uint256) {
        return allOrderbooks.length;
    }

    // Set immutable, consistent, one rule for orderbook implementation
    function _createImpl() internal {
        address addr;
        bytes memory bytecode = type(Orderbook).creationCode;
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
