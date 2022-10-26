// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "../interfaces/IOrderbook.sol";
import "../security/Initializable.sol";
import "../libraries/TransferHelper.sol";
import "../interfaces/IERC20Minimal.sol";
import "../libraries/NewOrderLibrary.sol";
import "../libraries/NewOrderLinkedList.sol";
import "../libraries/NewOrderQueue.sol";

contract Orderbook is IOrderbook, Initializable {
    using NewOrderLibrary for NewOrderLibrary.Order;
    using NewOrderLinkedList for NewOrderLinkedList.PriceLinkedList;
    using NewOrderQueue for NewOrderQueue.OrderQueue;

    // Pair Struct
    struct Pair {
        address base;
        address quote;
        uint256 baseDecimals;
        uint256 quoteDecimals;
    }

    Pair private pair;

    NewOrderLinkedList.PriceLinkedList private priceLists;
    NewOrderQueue.OrderQueue private orderQueue;
    NewOrderLibrary.Order[] public orders;
    
    function initialize(
        address base_,
        address quote_,
        address engine_
    ) public initializer {
        pair = Pair(base_, quote_, IERC20Minimal(base_).decimals(), IERC20Minimal(quote_).decimals());
        orderQueue.engine = engine_;
    }

    function getOrderDepositAmount(uint256 orderId)
        external
        view
        returns (uint256 depositAmount)
    {
        return orders[orderId].depositAmount;
    }

    function placeBid(
        address owner,
        uint256 price,
        uint256 amount
    ) external {
        /// Create order and save to order book
        orderQueue._initialize(price, false);
        NewOrderLibrary.Order memory order = NewOrderLibrary._createOrder(owner, false, price, pair.base, amount);
        priceLists._insert(false, price);
        orderQueue._enqueue(price, false, orders.length);
        orders.push(order);
        // event
    }

    function placeAsk(
        address owner,
        uint256 price,
        uint256 amount
    ) external {
        /// Create order and save to order book
        orderQueue._initialize(price, false);
        NewOrderLibrary.Order memory order = NewOrderLibrary._createOrder(owner, true, price, pair.quote, amount);
        priceLists._insert(true, price);
        orderQueue._enqueue(price, true, orders.length);
        orders.push(order);
        // event
    }

    function cancelOrder(uint256 orderId, address owner) external {
        require(msg.sender == orderQueue.engine, "Only engine can dequeue");
        NewOrderLibrary.Order memory order = orders[orderId];
        require(order.owner == owner, "Only owner can cancel order");
        delete orders[orderId];
        TransferHelper.safeTransfer(order.deposit, owner, order.depositAmount);
        // event
    }

    // get required amount for executing the order
    function getRequired(uint256 orderId, uint256 amount)
        public
        view
        returns (uint256)
    {
        NewOrderLibrary.Order memory order = orders[orderId];
        // if order is ask, required amount is quoteAmount / price, converting the number converting decimal from quote to base, otherwise baseAmount * price, converting decimal from base to quote
        uint256 pIn = order.isAsk ? (amount*pair.baseDecimals) / (order.price*pair.quoteDecimals)  : (amount*pair.quoteDecimals) * (order.price*pair.baseDecimals);
        return pIn / 1e8;
    }

    function execute(
        uint256 orderId,
        address sender,
        uint256 amount
    ) external {
        NewOrderLibrary.Order memory order = orders[orderId];
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
        return priceLists._heads();
    }

    function mktPrice() external view returns (uint256) {
        return priceLists._mktPrice();
    }
    

    /////////////////////////////////
    ///    Order queue methods    ///
    /////////////////////////////////
    function isInitialized(uint256 price, bool isAsk)
        public
        view
        returns (bool)
    {
        return orderQueue._isInitialized(price, isAsk);
    }

    function dequeue(uint256 price, bool isAsk)
        external
        returns (uint256 orderId)
    {
        require(msg.sender == orderQueue.engine, "Only engine can dequeue");
        require(!orderQueue._isEmpty(price, isAsk), "Queue is empty");
        orderId = orderQueue._dequeue(price, isAsk);
        if (isAsk) {
            if(orderQueue.askOrderQueueIndex[price].first > orderQueue.askOrderQueueIndex[price].last) {
                priceLists.askHead = priceLists._next(isAsk, price);
            }
            return orderId;
        } else {
            if(orderQueue.bidOrderQueueIndex[price].first > orderQueue.bidOrderQueueIndex[price].last) {
                priceLists.bidHead = priceLists._next(isAsk, price);
            }
            return orderId;
        }
    }

    function length(uint256 price, bool isAsk) public view returns (uint256) {
        return orderQueue._length(price, isAsk);
    }

    function isEmpty(uint256 price, bool isAsk) public view returns (bool) {
        return orderQueue._isEmpty(price, isAsk);
    }
}
