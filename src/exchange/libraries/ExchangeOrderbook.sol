// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

library ExchangeOrderbook {
    // Order struct
    struct Order {
        address owner;
        uint256 price;
        uint256 depositAmount;
    }

    // Order Linked List
    struct OrderStorage {
        /// Hashmap-style linked list of prices to route orders
        // key: price, value: order indices linked hashmap
        mapping(uint256 => mapping(uint32 => uint32)) list;
        mapping(uint32 => Order) orders;
        // Head of the linked list(i.e. lowest ask price / highest bid price)
        mapping(uint256 => uint32) head;
        // count of the orders, used for array allocation
        uint32 count;
        address engine;
        Order dormantOrder;
    }

    error OrderIdIsZero(uint32 id);
    error PriceIsZero(uint256 price);

    // for orders, lower depositAmount are next, higher depositAmount comes first
    function _insertId(OrderStorage storage self, uint256 price, uint32 id, uint256 amount) internal {
        uint32 last = 0;
        uint32 head = self.head[price];
        mapping(uint32 => uint32) storage list = self.list[price];
        mapping(uint32 => Order) storage orders = self.orders;
        // insert order to the linked list
        // if the list is empty
        if (head == 0 || amount > self.orders[head].depositAmount) {
            self.head[price] = id;
            list[id] = head;
            return;
        }
        // Traverse through list until we find the right spot where id's deposit amount is higher than next
        while (head != 0) {
            // what if order deposit amount is bigger than the next order's deposit amount?
            uint32 next = list[head];
            if (amount < orders[next].depositAmount) {
                // Keep traversing
                head = list[head];
                last = next;
            } else if (amount > orders[next].depositAmount) {
                // This is either order is cancelled or order is at the end of the list
                if (orders[next].depositAmount == 0) {
                    // Insert order at the end of the list
                    list[head] = id;
                    list[id] = 0;
                    return;
                }
                // Insert order in the middle of the list
                list[head] = id;
                list[id] = next;
                return;
            }
            // what if there is same order with same deposit amount?
            else if (amount == orders[next].depositAmount) {
                list[id] = list[next];
                list[next] = id;
                return;
            }
        }
    }

    // pop front
    function _fpop(OrderStorage storage self, uint256 price) internal returns (uint256) {
        uint32 first = self.head[price];
        if (first == 0) {
            return 0;
        }
        uint32 next = self.list[price][first];
        self.head[price] = next;
        delete self.list[price][first];
        return first;
    }

    function _createOrder(OrderStorage storage self, address owner, uint256 price, uint256 depositAmount)
        internal
        returns (uint32 id, bool foundDmt)
    {
        if (price == 0) {
            revert PriceIsZero(price);
        }
        Order memory order = Order({owner: owner, price: price, depositAmount: depositAmount});
        // set foundDmt to false by default
        foundDmt = false;
        // In order to prevent order overflow, order id must start from 1
        self.count = self.count == 0 || self.count == type(uint32).max ? 1 : self.count + 1;
        // check if the order already exists
        if (self.orders[self.count].owner != address(0)) {
            // store canceling order to dormantOrder
            self.dormantOrder = self.orders[self.count];
            // cancel the dormant order and set foundDmt to true
            _deleteOrder(self, self.count);
            foundDmt = true;
        }
        // insert order
        self.orders[self.count] = order;
        return (self.count, foundDmt == true);
    }

    function _decreaseOrder(OrderStorage storage self, uint32 id, uint256 amount, uint256 dust, bool clear)
        internal
        returns (uint256 sendFund, uint256 deletePrice)
    {
        uint256 decreased = self.orders[id].depositAmount < amount ? 0 : self.orders[id].depositAmount - amount;
        // remove dust
        if (decreased <= dust || clear) {
            decreased = self.orders[id].depositAmount;
            deletePrice = _deleteOrder(self, id);
            return (decreased, deletePrice);
        } else {
            self.orders[id].depositAmount = decreased;
            return (amount, deletePrice);
        }
    }

    function _deleteOrder(OrderStorage storage self, uint32 id) internal returns (uint256 deletePrice) {
        uint256 price = self.orders[id].price;
        uint32 last = 0;
        uint32 head = self.head[price];
        uint32 next;
        uint16 i;
        mapping(uint32 => uint32) storage list = self.list[price];
        // delete id in the order linked list
        if (head == id) {
            self.head[price] = list[head];
            delete list[id];
        } else {
            // search for the order id in the linked list
            while (head != 0) {
                next = list[head];
                if (next == id) {
                    list[head] = list[next];
                    delete list[id];
                    break;
                }
                last = head;
                head = next;
                ++i;
            }
        }
        // delete order
        delete self.orders[id];
        return self.head[price] == 0 ? price : 0;
    }

    function _nextMakeId(OrderStorage storage self) internal view returns (uint32) {
        return self.count == 0 || self.count == type(uint32).max ? 1 : self.count + 1;
    }

    // show n order ids at the price in the orderbook
    function _getOrderIds(OrderStorage storage self, uint256 price, uint32 n) internal view returns (uint32[] memory) {
        uint32 head = self.head[price];
        uint32[] memory orders = new uint32[](n);
        uint32 i = 0;
        while (head != 0 && i < n) {
            orders[i] = head;
            head = self.list[price][head];
            i++;
        }
        return orders;
    }

    function _getOrders(OrderStorage storage self, uint256 price, uint32 n) internal view returns (Order[] memory) {
        uint32 head = self.head[price];
        Order[] memory orders = new Order[](n);
        uint32 i = 0;
        while (head != 0 && i < n) {
            orders[i] = self.orders[head];
            head = self.list[price][head];
            i++;
        }
        return orders;
    }

    function _getOrdersPaginated(OrderStorage storage self, uint256 price, uint32 start, uint32 end)
        internal
        view
        returns (Order[] memory)
    {
        uint32 head = self.head[price];
        Order[] memory orders = new Order[](end - start);
        uint32 i = 0;
        while (head != 0 && i < start) {
            head = self.list[price][head];
            i++;
        }
        if (head == 0) {
            return orders;
        }
        while (head != 0 && i < end) {
            orders[i] = self.orders[head];
            head = self.list[price][head];
            i++;
        }
        return orders;
    }

    function _head(OrderStorage storage self, uint256 price) internal view returns (uint32) {
        return self.head[price];
    }

    function _isEmpty(OrderStorage storage self, uint256 price) internal view returns (bool) {
        return self.head[price] == 0;
    }

    function _next(OrderStorage storage self, uint256 price, uint32 curr) internal view returns (uint32) {
        return self.list[price][curr];
    }

    function _getOrder(OrderStorage storage self, uint32 id) internal view returns (Order memory) {
        return self.orders[id];
    }
}
