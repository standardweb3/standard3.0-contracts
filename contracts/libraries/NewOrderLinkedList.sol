// SPDX-License-Identifier: Apache-2.0

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
    }


    function _heads(
        PriceLinkedList storage self
    ) internal view returns (uint256, uint256) {
        return (self.askHead, self.bidHead);
    }

    function _mktPrice(
        PriceLinkedList storage self
    ) internal view returns (uint256) {
        require(self.bidHead > 0 && self.askHead > 0, "No orders matched yet");
        return (self.bidHead + self.askHead) / 2;
    }

    function _next(PriceLinkedList storage self, bool isAsk, uint256 price) internal view returns (uint256) {
        if (isAsk) {
            return self.askPrices[price];
        } else {
            return self.bidPrices[price];
        }
    }

    // for askPrices, lower ones are next, for bidPrices, higher ones are next
    function _insert(PriceLinkedList storage self, bool isAsk, uint256 price) internal {
        // insert ask price to the linked list
        if (isAsk) {
            if (self.askHead == 0) {
                self.askHead = price;
                return;
            }
            uint256 last = self.askHead;
            // Traverse through list until we find the right spot
            while (price < last) {
                last = self.askPrices[last];
            }
            // what if price is the lowest?
            // last is zero because it is null in solidity
            if (last == 0) {
                self.askPrices[price] = last;
                self.askHead = price;
            }
            // what if price is in the middle of the list?
            else if (self.askPrices[last] < price) {
                self.askPrices[price] = self.askPrices[last];
                self.askPrices[last] = price;
            }
            // what if price is already included?
            else if (price == last) {
                // do nothing
            }
            // what if price is the highest?
            else {
                self.askPrices[price] = last;
            }
        }
        // insert bid price to the linked list
        else {
            if (self.bidHead == 0) {
                self.bidHead = price;
                return;
            }
            uint256 last = self.bidHead;
            // Traverse through list until we find the right spot
            while (price > last) {
                last = self.bidPrices[last];
            }
            // what if price is the highest?
            if (last == 0) {
                self.bidPrices[price] = last;
                self.bidHead = price;
            }
            // what if price is in the middle of the list?
            else if (self.bidPrices[last] > price) {
                self.bidPrices[price] = self.bidPrices[last];
                self.bidPrices[last] = price;
            }
            // what if price is the lowest?
            else {
                self.bidPrices[price] = last;
            }
        }
    }
}