// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.10;

library NewOrderQueue {

    struct QueueIndex {
        uint first;
        uint last;
    }

    struct OrderQueue {
         // Ask Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) askOrderQueue;
    // Ask Order book queue's indices (key: Price, value: first and last index of orders by price)
    mapping(uint256 => QueueIndex) askOrderQueueIndex;
    // Bid Order book storage (key: (Price, Index), value: orderId)
    mapping(bytes32 => uint256) bidOrderQueue;
    // Bid Order book queue's indices (key: Price, value: first and last index of orders by price)
    mapping(uint256 => QueueIndex) bidOrderQueueIndex;
    address engine;
    }

    function _getOrderKey(uint256 price, uint256 index)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(price, index));
    }

    function _initialize(OrderQueue storage self, uint256 price, bool isAsk) internal {
        if(_isInitialized(self, price, isAsk)) { return; }
        if (isAsk) {
            self.askOrderQueueIndex[price] = QueueIndex({
                first: 1,
                last: 0
            }); 
        } else {
            self.bidOrderQueueIndex[price] = QueueIndex({
                first: 1,
                last: 0
            }); 
        }
    }

    function _isInitialized(OrderQueue storage self, uint256 price, bool isAsk)
        internal
        view
        returns (bool)
    {
        if (isAsk) {
            return self.askOrderQueueIndex[price].first == 0 &&
                self.askOrderQueueIndex[price].last == 0;
        } else {
            return self.bidOrderQueueIndex[price].first == 0 && 
                self.bidOrderQueueIndex[price].last == 0;
        }
    }

    function _initializeQueue(OrderQueue storage self, uint256 price, bool isAsk) internal {
        if (isAsk) {
            self.askOrderQueueIndex[price].first = 1;
            self.askOrderQueueIndex[price].last = 0;
        } else {
            self.bidOrderQueueIndex[price].first = 1;
            self.bidOrderQueueIndex[price].last = 0;
        }
    }

    function _enqueue(
        OrderQueue storage self,
        uint256 price,
        bool isAsk,
        uint256 orderId
    ) internal {
        if (isAsk) {
            self.askOrderQueueIndex[price].last += 1;
            self.askOrderQueue[_getOrderKey(price, self.askOrderQueueIndex[price].last)] = orderId;
        } else {
            self.bidOrderQueueIndex[price].last += 1;
            self.bidOrderQueue[_getOrderKey(price, self.bidOrderQueueIndex[price].last)] = orderId;
        }
    }

    function _dequeue(OrderQueue storage self, uint256 price, bool isAsk)
        internal
        returns (uint256 orderId)
    {
        require(msg.sender == self.engine, "Only engine can dequeue");
        require(!_isEmpty(self, price, isAsk), "Queue is empty");
        if (isAsk) {
            orderId = self.askOrderQueue[_getOrderKey(price, self.askOrderQueueIndex[price].first)];
            delete self.askOrderQueue[_getOrderKey(price, self.askOrderQueueIndex[price].first)];
            self.askOrderQueueIndex[price].first += 1;
            return orderId;
        } else {
            orderId = self.bidOrderQueue[_getOrderKey(price, self.bidOrderQueueIndex[price].first)];
            delete self.bidOrderQueue[_getOrderKey(price, self.bidOrderQueueIndex[price].first)];
            self.bidOrderQueueIndex[price].first += 1;
            return orderId;
        }
    }

    function _length(OrderQueue storage self, uint256 price, bool isAsk) internal view returns (uint256) {
        if (isAsk) {
            if (self.askOrderQueueIndex[price].first > self.askOrderQueueIndex[price].last) {
                return 0;
            } else {
                return self.askOrderQueueIndex[price].last - self.askOrderQueueIndex[price].first + 1;
            }
        } else {
            if (self.bidOrderQueueIndex[price].first > self.bidOrderQueueIndex[price].last) {
                return 0;
            } else {
                return self.bidOrderQueueIndex[price].last - self.bidOrderQueueIndex[price].first + 1;
            }
        }
    }

    function _isEmpty(OrderQueue storage self, uint256 price, bool isAsk) internal view returns (bool) {
        return _length(self, price, isAsk) == 0 || !_isInitialized(self, price, isAsk);
    }
}