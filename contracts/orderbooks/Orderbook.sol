// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../interfaces/IOrderbook.sol";
import "../interfaces/IOrder.sol";
import "../interfaces/IEngine.sol";
import "../libraries/Initializable.sol";

contract Orderbook is IOrderbook, Initializable {
    // id of the pair
    uint256 public id;
    // pair name (i.e. ETH/DAI, <Bid/Ask>, <Base/Quote>)
    string public pairName;
    // address of bid asset
    address public bid;
    // address of ask asset
    address public ask;
    // address of the factory
    address public orderFactory;
    // address of the engine
    address public engine;

    // Order struct
    struct Order {
        address owner;
        bool isAsk;
        uint256 price;
        address deposit;
        uint256 depositAmount;
        uint256 filled;
    }

    // Order book hashmap
    Order[] public orders;
    // Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) internal askOrderQueue;
    // Order book queue's last index (key: Price, value: last index of orders by price)
    mapping(uint256 => uint256) internal askOrderFirst;
    // Order book queue's first index (key: Price, value: first index of orders by price)
    mapping(uint256 => uint256) internal askOrderLast;
    // Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) internal bidOrderQueue;
    // Order book queue's last index (key: Price, value: last index of orders by price)
    mapping(uint256 => uint256) internal bidOrderFirst;
    // Order book queue's first index (key: Price, value: first index of orders by price)
    mapping(uint256 => uint256) internal bidOrderLast;

    function initialize(
        uint256 id_,
        string memory pairName_,
        address bid_,
        address ask_,
        address orderFactory_,
        address engine_
    ) public initializer  {
        id = id_;
        pairName = pairName_;
        bid = bid_;
        ask = ask_;
        orderFactory = orderFactory_;
        engine = engine_;
    }

    function pairInfo()
        external
        view
        returns (
            string memory,
            uint256,
            address,
            address
        )
    {
        uint256 mktPrice = IEngine(engine).mktPrice(bid, ask);
        return (pairName, mktPrice, bid, ask);
    }

    function getOrderKey(uint256 price, uint256 index)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(price, index));
    }

    function getOrder(uint256 orderId) external view returns (address order) {
        return orders[orderId];
    }

    function getQuote(address deposit) external view returns (address quote) {
        if (deposit == bid) {
            return ask;
        } else if (deposit == ask) {
            return bid;
        } else {
            revert("Invalid deposit");
        }
    }

    function _createOrder(
        address owner_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) internal       pure
returns (Order memory order) {
        Order memory order = Order({
            owner: owner_,
            isAsk: isAsk_,
            price: price_,
            deposit: deposit_,
            depositAmount: depositAmount_,
            filled: 0
        });
        return order;
    }

    function placeBid(uint256 price, uint256 amount) external {
        /// Create order and save to order book
        if (!isInitialized(price, false)) {
            bidOrderFirst[price] = 1;
            bidOrderLast[price] = 0;
        }
        (address order) = IOrderFactory(orderFactory)
            .createOrder(
                id,
                msg.sender,
                address(this),
                bid,
                false,
                price,
                ask,
                amount
            );
        _enqueue(price, false, orderId);
        orders.push(order);
        // event
    }

    function placeAsk(uint256 price, uint256 amount) external {
        /// Create order and save to order book
        if (!isInitialized(price, true)) {
            askOrderFirst[price] = 1;
            askOrderLast[price] = 0;
        }
        (address order, uint256 orderId) = IOrderFactory(orderFactory)
            .createOrder(
                id,
                msg.sender,
                address(this),
                ask,
                true,
                price,
                bid,
                amount
            );
        _enqueue(price, true, orderId);
        orders.push(order);
        // send deposit to order

        // event
    }

    function isInitialized(uint256 price, bool isAsk)
        public
        view
        returns (bool)
    {
        if (isAsk) {
            return askOrderFirst[price] == 0 && askOrderLast[price] == 0;
        } else {
            return bidOrderFirst[price] == 0 && bidOrderLast[price] == 0;
        }
    }

    function _initializeQueue(uint256 price, bool isAsk) internal {
        if (isAsk) {
            askOrderFirst[price] = 1;
            askOrderLast[price] = 0;
        } else {
            bidOrderFirst[price] = 1;
            bidOrderLast[price] = 0;
        }
    }

    function _enqueue(
        uint256 price,
        bool isAsk,
        uint256 orderId
    ) internal {
        if (isAsk) {
            askOrderLast[price] += 1;
            askOrderQueue[getOrderKey(price, askOrderLast[price])] = orderId;
        } else {
            bidOrderLast[price] += 1;
            bidOrderQueue[getOrderKey(price, bidOrderLast[price])] = orderId;
        }
    }

    function dequeue(uint256 price, bool isAsk)
        external
        returns (uint256 orderId)
    {
        require(msg.sender == engine, "Only engine can dequeue");
        require(!isEmpty(price, isAsk), "Queue is empty");
        if (isAsk) {
            orderId = askOrderQueue[getOrderKey(price, askOrderFirst[price])];
            delete askOrderQueue[getOrderKey(price, askOrderFirst[price])];
            askOrderFirst[price] += 1;
            return orderId;
        } else {
            orderId = bidOrderQueue[getOrderKey(price, bidOrderFirst[price])];
            delete bidOrderQueue[getOrderKey(price, bidOrderFirst[price])];
            bidOrderFirst[price] += 1;
            return orderId;
        }
    }

    function length(uint256 price, bool isAsk)
        public
        view
        returns (uint256)
    {
        if (isAsk) {
            if (askOrderFirst[price] > askOrderLast[price]) {
                return 0;
            } else {
                return askOrderLast[price] - askOrderFirst[price] + 1;
            }
        } else {
            if (bidOrderFirst[price] > bidOrderLast[price]) {
                return 0;
            } else {
                return bidOrderLast[price] - bidOrderFirst[price] + 1;
            }
        }
    }

    function isEmpty(uint256 price, bool isAsk) public view returns (bool) {
        return length(price, isAsk) == 0 || !isInitialized(price, isAsk);
    }
}
