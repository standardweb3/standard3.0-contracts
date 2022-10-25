// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../interfaces/IOrderbook.sol";
import "../libraries/Initializable.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IERC20Minimal.sol";

contract Orderbook is IOrderbook, Initializable {

    // Pair Struct
    struct Pair {
        address base;
        address quote;
        uint256 baseDecimals;
        uint256 quoteDecimals;
    }

    Pair private pair;
    
    // address of engine
    address private engine;

    // Order struct
    struct Order {
        address owner;
        bool isAsk;
        uint256 price;
        address deposit;
        uint256 depositAmount;
        uint256 filled;
    }

    struct QueueIndex {
        uint first;
        uint last;
    }

    /// Hashmap-style linked list of prices to route orders
    // key: price, value: next_price (next_price > price)
    mapping(uint256 => uint256) public bidPrices;
    // key: price, value: next_price (next_price < price)
    mapping(uint256 => uint256) public askPrices;

    // Head of the bid price linked list(i.e. highest bid price)
    uint256 public bidHead;
    // Head of the ask price linked list(i.e. lowest ask price)
    uint256 public askHead;

    // Order book hashmap
    Order[] public orders;
    // Ask Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) internal askOrderQueue;
    // Ask Order book queue's indices (key: Price, value: first and last index of orders by price)
    mapping(uint256 => QueueIndex) internal askOrderQueueIndex;
    // Bid Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) internal bidOrderQueue;
    // Bid Order book queue's indices (key: Price, value: first and last index of orders by price)
    mapping(uint256 => QueueIndex) internal bidOrderQueueIndex;
    
    function initialize(
        address base_,
        address quote_,
        address engine_
    ) public initializer {
        pair = Pair(base_, quote_, IERC20Minimal(base_).decimals(), IERC20Minimal(quote_).decimals());
        engine = engine_;
    }

    function getOrderDepositAmount(uint256 orderId)
        external
        view
        returns (uint256 depositAmount)
    {
        return orders[orderId].depositAmount;
    }

    function _createOrder(
        address owner_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) internal pure returns (Order memory order) {
        Order memory ord = Order({
            owner: owner_,
            isAsk: isAsk_,
            price: price_,
            deposit: deposit_,
            depositAmount: depositAmount_,
            filled: 0
        });
        return ord;
    }

    function placeBid(
        address owner,
        uint256 price,
        uint256 amount
    ) external {
        /// Create order and save to order book
        _initialize(price, false);
        Order memory order = _createOrder(owner, false, price, pair.base, amount);
        _insert(false, price);
        _enqueue(price, false, orders.length);
        orders.push(order);
        // event
    }

    function placeAsk(
        address owner,
        uint256 price,
        uint256 amount
    ) external {
        /// Create order and save to order book
        _initialize(price, false);
        Order memory order = _createOrder(owner, true, price, pair.quote, amount);
        _insert(true, price);
        _enqueue(price, true, orders.length);
        orders.push(order);
        // event
    }

    // get required amount for executing the order
    function getRequired(uint256 orderId, uint256 amount)
        public
        view
        returns (uint256)
    {
        Order memory order = orders[orderId];
        // if order is ask, required amount is quoteAmount / price, converting the number converting decimal from quote to base, otherwise baseAmount * price, converting decimal from base to quote
        uint256 pIn = order.isAsk ? (amount*pair.baseDecimals) / (order.price*pair.quoteDecimals)  : (amount*pair.quoteDecimals) * (order.price*pair.baseDecimals);
        return pIn / 1e8;
    }

    function execute(
        uint256 orderId,
        address sender,
        uint256 amount
    ) external {
        Order memory order = orders[orderId];
        uint256 required = getRequired(orderId, amount);
        // if the order is ask order on the base/quote pair
        if (order.isAsk) {
            // owner is buyer, and sender is seller. if buyer is asking for base asset with quote asset in deposit
            // then the converted amount is <base>/<quote> == (baseAmount * 10^qDecimal) / (quoteAmount * 10^bDecimal)
            // send deposit as quote asset to seller
            TransferHelper.safeTransfer(order.deposit, sender, amount);
            // send claimed amount of base asset to buyer
            TransferHelper.safeTransfer(pair.base, order.owner, required);
        }
        // if the order is bid order on the base/quote pair
        else {
            // owner is seller, and sender is buyer. buyer is asking for quote asset with base asset in deposit
            // then the converted amount is <base>/<quote> == depositAmount / claimAmount => claimAmount == depositAmount / price
            // send deposit as base asset to buyer
            TransferHelper.safeTransfer(order.deposit, order.owner, amount);
            // send claimed amount of quote asset to seller
            TransferHelper.safeTransfer(pair.quote, sender, amount);
        }
        uint256 absDiff = (order.depositAmount > amount)
            ? (order.depositAmount - amount)
            : (amount - order.depositAmount);
        if (absDiff <= amount / 1e6) {
            delete orders[orderId];
        } else {
            // update deposit amount
            order.depositAmount -= amount;
            // update filled amount
            order.filled += amount;
        }
    }
    /////////////////////////////////
    /// Price linked list methods ///
    /////////////////////////////////

    function heads() external view returns (uint256, uint256) {
        return (askHead, bidHead);
    }

    function mktPrice() external view returns (uint256) {
        require(bidHead > 0 && askHead > 0, "No orders matched yet");
        return (bidHead + askHead) / 2;
    }

    function _next(bool isAsk, uint256 price) internal view returns (uint256) {
        if (isAsk) {
            return askPrices[price];
        } else {
            return bidPrices[price];
        }
    }

    // for askPrices, lower ones are next, for bidPrices, higher ones are next
    function _insert(bool isAsk, uint256 price) internal {
        // insert ask price to the linked list
        if (isAsk) {
            if (askHead == 0) {
                askHead = price;
                return;
            }
            uint256 last = askHead;
            // Traverse through list until we find the right spot
            while (price < last) {
                last = askPrices[last];
            }
            // what if price is the lowest?
            // last is zero because it is null in solidity
            if (last == 0) {
                askPrices[price] = last;
                askHead = price;
            }
            // what if price is in the middle of the list?
            else if (askPrices[last] < price) {
                askPrices[price] = askPrices[last];
                askPrices[last] = price;
            }
            // what if price is already included?
            else if (price == last) {
                // do nothing
            }
            // what if price is the highest?
            else {
                askPrices[price] = last;
            }
        }
        // insert bid price to the linked list
        else {
            if (bidHead == 0) {
                bidHead = price;
                return;
            }
            uint256 last = bidHead;
            // Traverse through list until we find the right spot
            while (price > last) {
                last = bidPrices[last];
            }
            // what if price is the highest?
            if (last == 0) {
                bidPrices[price] = last;
                bidHead = price;
            }
            // what if price is in the middle of the list?
            else if (bidPrices[last] > price) {
                bidPrices[price] = bidPrices[last];
                bidPrices[last] = price;
            }
            // what if price is the lowest?
            else {
                bidPrices[price] = last;
            }
        }
    }

    /////////////////////////////////
    ///    Order queue methods    ///
    /////////////////////////////////
    function _getOrderKey(uint256 price, uint256 index)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(price, index));
    }

    function _initialize(uint256 price, bool isAsk) internal {
        if(isInitialized(price, isAsk)) { return; }
        if (isAsk) {
            askOrderQueueIndex[price] = QueueIndex({
                first: 1,
                last: 0
            }); 
        } else {
            bidOrderQueueIndex[price] = QueueIndex({
                first: 1,
                last: 0
            }); 
        }
    }

    function isInitialized(uint256 price, bool isAsk)
        public
        view
        returns (bool)
    {
        if (isAsk) {
            return askOrderQueueIndex[price].first == 0 &&
                askOrderQueueIndex[price].last == 0;
        } else {
            return bidOrderQueueIndex[price].first == 0 && 
                bidOrderQueueIndex[price].last == 0;
        }
    }

    function _initializeQueue(uint256 price, bool isAsk) internal {
        if (isAsk) {
            askOrderQueueIndex[price].first = 1;
            askOrderQueueIndex[price].last = 0;
        } else {
            bidOrderQueueIndex[price].first = 1;
            bidOrderQueueIndex[price].last = 0;
        }
    }

    function _enqueue(
        uint256 price,
        bool isAsk,
        uint256 orderId
    ) internal {
        if (isAsk) {
            askOrderQueueIndex[price].last += 1;
            askOrderQueue[_getOrderKey(price, askOrderQueueIndex[price].last)] = orderId;
        } else {
            bidOrderQueueIndex[price].last += 1;
            bidOrderQueue[_getOrderKey(price, bidOrderQueueIndex[price].last)] = orderId;
        }
    }

    function dequeue(uint256 price, bool isAsk)
        external
        returns (uint256 orderId)
    {
        require(msg.sender == engine, "Only engine can dequeue");
        require(!isEmpty(price, isAsk), "Queue is empty");
        if (isAsk) {
            orderId = askOrderQueue[_getOrderKey(price, askOrderQueueIndex[price].first)];
            delete askOrderQueue[_getOrderKey(price, askOrderQueueIndex[price].first)];
            askOrderQueueIndex[price].first += 1;
            if(askOrderQueueIndex[price].first > askOrderQueueIndex[price].last) {
                askHead = _next(isAsk, price);
            }
            return orderId;
        } else {
            orderId = bidOrderQueue[_getOrderKey(price, bidOrderQueueIndex[price].first)];
            delete bidOrderQueue[_getOrderKey(price, bidOrderQueueIndex[price].first)];
            bidOrderQueueIndex[price].first += 1;
            if(bidOrderQueueIndex[price].first > bidOrderQueueIndex[price].last) {
                bidHead = _next(isAsk, price);
            }
            return orderId;
        }
    }

    function length(uint256 price, bool isAsk) public view returns (uint256) {
        if (isAsk) {
            if (askOrderQueueIndex[price].first > askOrderQueueIndex[price].last) {
                return 0;
            } else {
                return askOrderQueueIndex[price].last - askOrderQueueIndex[price].first + 1;
            }
        } else {
            if (bidOrderQueueIndex[price].first > bidOrderQueueIndex[price].last) {
                return 0;
            } else {
                return bidOrderQueueIndex[price].last - bidOrderQueueIndex[price].first + 1;
            }
        }
    }

    function isEmpty(uint256 price, bool isAsk) public view returns (bool) {
        return length(price, isAsk) == 0 || !isInitialized(price, isAsk);
    }
}
