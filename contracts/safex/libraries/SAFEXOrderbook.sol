// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

library SAFEXOrderbook {
    // Order struct
    struct Order {
        address owner;
        uint256 depositAmount;
    }

    // Order Linked List
    struct OrderStorage {
        /// Hashmap-style linked list of prices to route orders
        // key: price, value: order indices linked hashmap
        mapping(uint256 => mapping(uint256 => uint256)) list;
        mapping(uint256 => Order) orders;
        // Head of the linked list(i.e. lowest ask price / highest bid price)
        mapping(uint256 => uint256) head;
        // count of the orders, used for array allocation
        uint256 count;
        address engine;
    }

    // for orders, lower depositAmount are next, higher depositAmount comes first
    function _insertId(
        OrderStorage storage self,
        uint256 price,
        uint256 id,
        uint256 amount
    ) internal {
        uint256 last = 0;
        uint256 head = self.head[price];
        // insert order to the linked list
        // if the list is empty
        if (head == 0) {
            self.head[price] = id;
            return;
        }
        // Traverse through list until we find the right spot where id's deposit amount is higher than next
        while (head != 0) {
            // what if order deposit amount is bigger than the next order's deposit amount?
            uint256 next = self.orders[head].depositAmount;
            if (amount > next) {
                // set next order id after input id
                self.list[price][id] = self.list[price][head];
                // set last order id before input id
                self.list[price][last] = id;
                return;
            }
            // what if order is canceled and order id still stays in the list?
            else if (next == 0) {
                // set next of next order id to the next order id of last order
                self.list[price][last] = self.list[price][head];
                // delete canceled order id
                delete self.list[price][head];
                // set head to the next order id of last order
                head = self.list[price][last];
                return;
            }
            // what if there is same order with same deposit amount?
            else if (next == amount) {
                // set input order id after next order id
                self.list[price][head] = self.list[price][id];
                // set last order id before next order id
                self.list[price][last] = self.list[price][head];
                return;
            }
            // if order deposit amount is lower than the next order's deposit amount
            else {
                // Keep traversing
                last = head;
                head = self.list[price][head];
            }
        }
    }

    // pop front
    function _fpop(
        OrderStorage storage self,
        uint256 price
    ) internal returns (uint256) {
        uint256 first = self.head[price];
        if (first == 0) {
            return 0;
        }
        uint256 next = self.list[price][first];
        self.head[price] = next;
        delete self.list[price][first];
        return first;
    }

    function _createOrder(
        OrderStorage storage self,
        address owner,
        uint256 depositAmount
    ) internal returns (uint256 id) {
        Order memory order = Order({
            owner: owner,
            depositAmount: depositAmount
        });
        // prevent order overflow, order id must start from 1
        self.count = self.count == 0 || self.count == type(uint256).max
            ? 1
            : self.count + 1;
        self.orders[self.count] = order;
        return self.count;
    }

    function _decreaseOrder(
        OrderStorage storage self,
        uint256 id,
        uint256 amount
    ) internal {
        uint256 decreased = self.orders[id].depositAmount - amount;
        if (decreased == 0) {
            _deleteOrder(self, id);
        } else {
            self.orders[id].depositAmount = decreased;
        }
    }

    function _deleteOrder(OrderStorage storage self, uint256 id) internal {
        delete self.orders[id];
    }

    // show n order ids at the price in the orderbook
    function _getOrderIds(
        OrderStorage storage self,
        uint256 price,
        uint n
    ) internal view returns (uint256[] memory) {
        uint256 head = self.head[price];
        uint256[] memory orders = new uint256[](n);
        uint256 i = 0;
        while (head != 0 && i < n) {
            orders[i] = head;
            head = self.list[price][head];
            i++;
        }
        return orders;
    }

    function _getOrders(
        OrderStorage storage self,
        uint256 price,
        uint n
    ) internal view returns (Order[] memory) {
        uint256 head = self.head[price];
        Order[] memory orders = new Order[](n);
        uint256 i = 0;
        while (head != 0 && i < n) {
            orders[i] = self.orders[head];
            head = self.list[price][head];
            i++;
        }
        return orders;
    }

    function _head(
        OrderStorage storage self,
        uint256 price
    ) internal view returns (uint256) {
        return self.head[price];
    }

    function _isEmpty(
        OrderStorage storage self,
        uint256 price
    ) internal view returns (bool) {
        return self.head[price] == 0;
    }

    function _next(
        OrderStorage storage self,
        uint256 price,
        uint256 curr
    ) internal view returns (uint256) {
        return self.list[price][curr];
    }

    function _getOrder(
        OrderStorage storage self,
        uint256 id
    ) internal view returns (Order memory) {
        return self.orders[id];
    }
}