import "../interfaces/IOrderbook.sol";
import "../../security/Initializable.sol";
import "../libraries/TransferHelper.sol";

contract Prices {
    // Price Linked List

    // key-key: bool for knowing isAsk key: price, value: next_price (next_price < price)
    mapping(bool => mapping(uint256 => uint256)) prices;

    struct PriceLinkedList {
        // Head of the bid price linked list(i.e. highest bid price)
        uint256 bidHead;
        // Head of the ask price linked list(i.e. lowest ask price)
        uint256 askHead;
        // Last matched price
        uint256 lmp;
    }

    PriceLinkedList internal heads;

    function _setLmp(uint256 lmp_) internal {
        heads.lmp = lmp_;
    }

    function _heads(
    ) internal view returns (uint256, uint256) {
        return (heads.bidHead, heads.askHead);
    }

    function _bidHead(
    ) internal view returns (uint256) {
        return heads.bidHead;
    }

    function _askHead(
    ) internal view returns (uint256) {
        return heads.askHead;
    }

    function _mktPrice(
    ) internal view returns (uint256) {
        require(
            (heads.bidHead > 0 && heads.askHead > 0) || heads.lmp > 0,
            "NoOrders"
        );
        return
            heads.bidHead > 0 && heads.askHead > 0
                ? (heads.bidHead + heads.askHead) / 2
                : heads.bidHead == 0 && heads.askHead == 0
                ? heads.lmp
                : (heads.bidHead + heads.askHead);
    }

    function _next(bool isAsk, uint256 price) internal view returns (uint256) {
        return prices[isAsk][price];
    }

    // for ask prices, lower ones are next, for bid prices, higher ones are next
    function _insert(bool isAsk, uint256 price) internal {
        // insert ask price to the linked list
        if (isAsk) {
            // what if price queue had not been initialized or price is the lowest?
            if (heads.askHead == 0 || price < heads.askHead) {
                heads.askHead = price;
                return;
            }
            uint256 last = heads.askHead;
            // Traverse through list until we find the right spot where inserting price is higher value than last
            while (price < last) {
                last = prices[isAsk][last];
            }
            // what if price is the lowest as lowest ask has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                prices[isAsk][price] = last;
                heads.askHead = price;
            }
            // what if price is already included in the queue?
            else if (last == price) {
                // End traversal as there is no need to traverse further
                return;
            }
            // what if price is in the middle of the list?
            else if (prices[isAsk][last] < price) {
                prices[isAsk][price] = prices[isAsk][last];
                prices[isAsk][last] = price;
            }
            // what if price is the highest?
            else {
                prices[isAsk][price] = last;
            }
        }
        // insert bid price to the linked list
        else {
            // what if price queue had not been initialized or price is the highest?
            if (heads.bidHead == 0 || price > heads.bidHead) {
                heads.bidHead = price;
                return;
            }
            uint256 last = heads.bidHead;
            // Traverse through list until we find the right spot where inserting price is lower value than last
            // Check for null value of last as well because it will always be null at the end of the list, returning true always
            while (price > last && last != 0) {
                last = prices[isAsk][last];
            }
            // what if price is the highest as highest bid has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                prices[isAsk][price] = last;
                heads.bidHead = price;
            }
            // what if price is in the middle of the list?
            else if (prices[isAsk][last] > price) {
                prices[isAsk][price] = prices[isAsk][last];
                prices[isAsk][last] = price;
            }
            // what if price is already included in the queue?
            else if (last == price) {
                // End traversal as there is no need to traverse further
                return;
            }
            // what if price is the lowest?
            else {
                prices[isAsk][price] = last;
            }
        }
    }
}

contract Orderbook {
    // Order struct
    struct Order {
        address owner;
        uint256 depositAmount;
    }

    /// Hashmap-style linked list of prices to route orders
    // key: price, value: order indices linked hashmap
    mapping(bool => mapping(uint256 => mapping(uint256 => uint256))) list;
    mapping(bool => mapping(uint256 => Order)) orders;
    // Heads of the order linked list(i.e. lowest ask price / highest bid price)
    mapping(bool => mapping(uint256 => uint256)) oHeads;

    // Order Linked List
    struct OrderStorage {
        // count of the orders, used for array allocation
        uint256 count;
        address engine;
    }

    OrderStorage internal orderStorage;

    // for orders, lower depositAmount are next, higher depositAmount comes first
    function _insertId(bool isAsk, uint256 price, uint256 id, uint256 amount) internal {
        uint256 last = 0;
        uint256 head = oHeads[isAsk][price];
        // insert order to the linked list
        // if the list is empty
        if (head == 0) {
            oHeads[isAsk][price] = id;
            return;
        }
        // Traverse through list until we find the right spot where id's deposit amount is higher than next
        while (head != 0) {
            // what if order deposit amount is bigger than the next order's deposit amount?
            if (amount > orders[isAsk][head].depositAmount) {
                // set next order id after input id
                list[isAsk][price][id] = list[isAsk][price][head];
                // set last order id before input id
                list[isAsk][price][last] = id;
                return;
            }
            // what if order is canceled and order id still stays in the list?
            else if (orders[isAsk][head].depositAmount == 0) {
                // set next of next order id to the next order id of last order
                list[isAsk][price][last] = list[isAsk][price][head];
                // delete canceled order id
                delete list[isAsk][price][head];
                // set head to the next order id of last order
                head = list[isAsk][price][last];
                return;
            }
            // what if there is same order with same deposit amount?
            else if (orders[isAsk][head].depositAmount == amount) {
                // set input order id after next order id
                list[isAsk][price][head] = list[isAsk][price][id];
                // set last order id before next order id
                list[isAsk][price][last] = list[isAsk][price][head];
                return;
            }
            // if order deposit amount is lower than the next order's deposit amount
            else {
                // Keep traversing
                last = head;
                head = list[isAsk][price][head];
            }
        }
    }

    // pop front
    function _fpop(bool isAsk, uint256 price) internal returns (uint256) {
        uint256 first = oHeads[isAsk][price];
        if (first == 0) {
            return 0;
        }
        uint256 next = list[isAsk][price][first];
        oHeads[isAsk][price] = next;
        delete list[isAsk][price][first];
        return first;
    }

    function _createOrder(
        bool isAsk,
        address owner,
        uint256 depositAmount
    ) internal returns (uint256 id) {
        Order memory order = Order({
            owner: owner,
            depositAmount: depositAmount
        });
        // prevent order overflow, order id must start from 1
        orderStorage.count = orderStorage.count == 0 ||
            orderStorage.count == type(uint256).max
            ? 1
            : orderStorage.count + 1;
        orders[isAsk][orderStorage.count] = order;
        return orderStorage.count;
    }

    function _decreaseOrder(bool isAsk, uint256 id, uint256 amount) internal {
        uint256 decreased = orders[isAsk][id].depositAmount - amount;
        if (decreased == 0) {
            _deleteOrder(isAsk, id);
        } else {
            orders[isAsk][id].depositAmount = decreased;
        }
    }

    function _deleteOrder(bool isAsk, uint256 id) internal {
        delete orders[isAsk][id];
    }

    // show n prices shown in the orderbook
    function _getPrices(bool isAsk, uint n) internal view returns (uint256[] memory) {
        uint256 i = 0;
        uint256[] memory prices = new uint256[](n);
        for (
            uint256 price = oHeads[isAsk][0];
            price != 0 && i < n;
            price = list[isAsk][0][price]
        ) {
            prices[i] = price;
            i++;
        }
        return prices;
    }

    // show n order ids at the price in the orderbook
    function _getOrderIds(
        bool isAsk,
        uint256 price,
        uint n
    ) internal view returns (uint256[] memory) {
        uint256 head = oHeads[isAsk][price];
        uint256[] memory ids = new uint256[](n);
        uint256 i = 0;
        while (head != 0 && i < n) {
            ids[i] = head;
            head = list[isAsk][price][head];
            i++;
        }
        return ids;
    }

    function _getOrders(
        bool isAsk,
        uint256 price,
        uint n
    ) internal view returns (Order[] memory ) {
        uint256 head = oHeads[isAsk][price];
        Order[] memory submittedOrders = new Order[](n);
        uint256 i = 0;
        while (head != 0 && i < n) {
            submittedOrders[i] = orders[isAsk][head];
            head = list[isAsk][price][head];
            i++;
        }
        return submittedOrders;
    }

    function _head(bool isAsk, uint256 price) internal view returns (uint256) {
        return oHeads[isAsk][price];
    }

    function _isEmpty(bool isAsk, uint256 price) internal view returns (bool) {
        return oHeads[isAsk][price] == 0;
    }

    function _next(
        bool isAsk,
        uint256 price,
        uint256 curr
    ) internal view returns (uint256) {
        return list[isAsk][price][curr];
    }

    function _getOrder(bool isAsk, uint256 id) internal view returns (Order memory) {
        return orders[isAsk][id];
    }
}

contract Orderbook2 is Initializable, Prices, Orderbook {
    // Pair Struct
    struct Pair {
        uint256 id;
        address base;
        address quote;
        address engine;
    }

    Pair private pair;

    uint64 private decDiff;
    bool private baseBquote;

    function initialize(
        uint256 id_,
        address base_,
        address quote_,
        address engine_
    ) external initializer {
        uint8 baseD = TransferHelper.decimals(base_);
        uint8 quoteD = TransferHelper.decimals(quote_);
        require(baseD <= 18 && quoteD <= 18, "DECIMALS");
        (uint8 diff, bool baseBquote_) = _absdiff(baseD, quoteD);
        decDiff = uint64(10 ** diff);
        baseBquote = baseBquote_;
        pair = Pair(id_, base_, quote_, engine_);
    }

    function _absdiff(uint8 a, uint8 b) internal pure returns (uint8, bool) {
        return (a > b ? a - b : b - a, a > b);
    }
}
