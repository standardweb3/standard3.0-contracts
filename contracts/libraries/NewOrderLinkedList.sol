// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

library NewOrderLinkedList {
    struct PriceLinkedList {
        /// Hashmap-style linked list of prices to route orders
        // key: price, value: next_price (next_price > price)
        mapping(uint256 => uint256) bidPrices;
        // key: price, value: next_price (next_price < price)
        mapping(uint256 => uint256) askPrices;
        // Head of the bid price linked list(i.e. highest bid price)
        uint256 bidHead;
        // Head of the ask price linked list(i.e. lowest ask price)
        uint256 askHead;
        // Last matched price
        uint256 lmp;
    }

   
    function _setLmp(
        PriceLinkedList storage self,
        uint256 lmp_
    ) internal {
        self.lmp = lmp_;
    }

    function _heads(
        PriceLinkedList storage self
    ) internal view returns (uint256, uint256) {
        return (self.bidHead, self.askHead);
    }

    function _bidHead(
        PriceLinkedList storage self
    ) internal view returns (uint256) {
        return self.bidHead;
    }

    function _askHead(
        PriceLinkedList storage self
    ) internal view returns (uint256) {
        return self.askHead;
    }

    function _mktPrice(
        PriceLinkedList storage self
    ) internal view returns (uint256) {
        require(
            self.bidHead > 0 && self.askHead > 0 || self.lmp > 0,
            "NoOrders"
        );
        return
            self.bidHead > 0 && self.askHead > 0
                ? (self.bidHead + self.askHead) / 2
                : self.bidHead == 0 && self.askHead == 0
                ? self.lmp
                : (self.bidHead + self.askHead);
    }

    function _next(
        PriceLinkedList storage self,
        bool isAsk,
        uint256 price
    ) internal view returns (uint256) {
        if (isAsk) {
            return self.askPrices[price];
        } else {
            return self.bidPrices[price];
        }
    }

    // for askPrices, lower ones are next, for bidPrices, higher ones are next
    function _insert(
        PriceLinkedList storage self,
        bool isAsk,
        uint256 price
    ) internal {
        // insert ask price to the linked list
        if (isAsk) {
            // what if price queue had not been initialized or price is the lowest?
            if (self.askHead == 0 || price < self.askHead) {
                self.askHead = price;
                return;
            }
            uint256 last = self.askHead;
            // Traverse through list until we find the right spot where inserting price is higher value than last
            while (price < last) {
                last = self.askPrices[last];
            }
            // what if price is the lowest as lowest ask has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                self.askPrices[price] = last;
                self.askHead = price;
            }
            // what if price is already included in the queue?
            else if (last == price) {
                // End traversal as there is no need to traverse further
                return;
            }
            // what if price is in the middle of the list?
            else if (self.askPrices[last] < price) {
                self.askPrices[price] = self.askPrices[last];
                self.askPrices[last] = price;
            }
            // what if price is the highest?
            else {
                self.askPrices[price] = last;
            }
        }
        // insert bid price to the linked list
        else {
            // what if price queue had not been initialized or price is the highest?
            if (self.bidHead == 0 || price > self.bidHead) {
                self.bidHead = price;
                return;
            }
            uint256 last = self.bidHead;
            // Traverse through list until we find the right spot where inserting price is lower value than last
            // Check for null value of last as well because it will always be null at the end of the list, returning true always
            while (price > last && last != 0) {
                last = self.bidPrices[last];
            }
            // what if price is the highest as highest bid has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                self.bidPrices[price] = last;
                self.bidHead = price;
            }
            // what if price is in the middle of the list?
            else if (self.bidPrices[last] > price) {
                self.bidPrices[price] = self.bidPrices[last];
                self.bidPrices[last] = price;
            }
            // what if price is already included in the queue?
            else if (last == price) {
                // End traversal as there is no need to traverse further
                return;
            }
            // what if price is the lowest?
            else {
                self.bidPrices[price] = last;
            }
        }
    }
}
