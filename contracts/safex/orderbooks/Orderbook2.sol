import "../interfaces/IOrderbook2.sol";
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

    PriceLinkedList internal pHeads;

    function _setLmp(uint256 lmp_) internal {
        pHeads.lmp = lmp_;
    }

    function _heads(
    ) internal view returns (uint256, uint256) {
        return (pHeads.bidHead, pHeads.askHead);
    }

    function _bidHead(
    ) internal view returns (uint256) {
        return pHeads.bidHead;
    }

    function _askHead(
    ) internal view returns (uint256) {
        return pHeads.askHead;
    }

    function _mktPrice(
    ) internal view returns (uint256) {
        require(
            (pHeads.bidHead > 0 && pHeads.askHead > 0) || pHeads.lmp > 0,
            "NoOrders"
        );
        return
            pHeads.bidHead > 0 && pHeads.askHead > 0
                ? (pHeads.bidHead + pHeads.askHead) / 2
                : pHeads.bidHead == 0 && pHeads.askHead == 0
                ? pHeads.lmp
                : (pHeads.bidHead + pHeads.askHead);
    }

    function _next(bool isAsk, uint256 price) internal view returns (uint256) {
        return prices[isAsk][price];
    }

    // for ask prices, lower ones are next, for bid prices, higher ones are next
    function _insert(bool isAsk, uint256 price) internal {
        // insert ask price to the linked list
        if (isAsk) {
            // what if price queue had not been initialized or price is the lowest?
            if (pHeads.askHead == 0 || price < pHeads.askHead) {
                pHeads.askHead = price;
                return;
            }
            uint256 last = pHeads.askHead;
            // Traverse through list until we find the right spot where inserting price is higher value than last
            while (price < last) {
                last = prices[isAsk][last];
            }
            // what if price is the lowest as lowest ask has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                prices[isAsk][price] = last;
                pHeads.askHead = price;
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
            if (pHeads.bidHead == 0 || price > pHeads.bidHead) {
                pHeads.bidHead = price;
                return;
            }
            uint256 last = pHeads.bidHead;
            // Traverse through list until we find the right spot where inserting price is lower value than last
            // Check for null value of last as well because it will always be null at the end of the list, returning true always
            while (price > last && last != 0) {
                last = prices[isAsk][last];
            }
            // what if price is the highest as highest bid has not even been initialized?
            // last is zero because it is null in solidity
            if (last == 0) {
                prices[isAsk][price] = last;
                pHeads.bidHead = price;
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

    /// Hashmap-style linked list of prices to route orders
    // key: price, value: order indices linked hashmap
    mapping(bool => mapping(uint256 => mapping(uint256 => uint256))) list;
    mapping(bool => mapping(uint256 => IOrderbook2.Order)) orders;
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
        IOrderbook2.Order memory order = IOrderbook2.Order({
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
    ) internal view returns (IOrderbook2.Order[] memory ) {
        uint256 head = oHeads[isAsk][price];
        IOrderbook2.Order[] memory submittedOrders = new IOrderbook2.Order[](n);
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

    function _getOrder(bool isAsk, uint256 id) internal view returns (IOrderbook2.Order memory) {
        return orders[isAsk][id];
    }
}

contract Orderbook2 is Initializable, Prices, Orderbook, IOrderbook2 {
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

    function setLmp(uint256 price) external {
        require(msg.sender == pair.engine, "IA");
        _setLmp(price);
    }

    function placeBid(address owner, uint256 price, uint256 amount) external {
        require(msg.sender == pair.engine, "IA");
        uint256 id = _createOrder(false, owner, amount);
        _insert(false, price);
        _insertId(false, price, id, amount);
    }

    function placeAsk(address owner, uint256 price, uint256 amount) external {
        require(msg.sender == pair.engine, "IA");
        uint256 id = _createOrder(true, owner, amount);
        _insert(true, price);
        _insertId(true, price, id, amount);
    }

    function cancelOrder(
        uint256 orderId,
        bool isAsk,
        address owner
    ) external returns (uint256 remaining, address base, address quote) {
        require(msg.sender == pair.engine, "IA");
        IOrderbook2.Order memory order = isAsk
            ? _getOrder(true, orderId)
            : _getOrder(false, orderId);
        require(order.owner == owner, "NOT_OWNER");
        isAsk
            ? _deleteOrder(true, orderId)
            : _deleteOrder(false, orderId);
        isAsk
            ? TransferHelper.safeTransfer(
                pair.quote,
                owner,
                order.depositAmount
            )
            : TransferHelper.safeTransfer(
                pair.base,
                owner,
                order.depositAmount
            );
        return (order.depositAmount, pair.base, pair.quote);
    }

    function execute(
        uint256 orderId,
        bool isAsk,
        uint256 price,
        address sender,
        uint256 amount
    ) external returns (address owner) {
        require(msg.sender == pair.engine, "IA");
        IOrderbook2.Order memory order = isAsk
            ? _getOrder(true, orderId)
            : _getOrder(false, orderId);
        /* if ask, converted quote amount is baseAmount * price,
         * converting the number converting decimal from base to quote,
         * otherwise quote amount is baseAmount / price, converting decimal from quote to base
         */
        uint256 converted = _convert(price, amount, !isAsk);
        converted = converted > order.depositAmount
            ? order.depositAmount
            : converted;
        // if the order is ask order on the base/quote pair
        if (isAsk) {
            // sender is matching ask order for base asset with quote asset
            // send converted amount of base asset from order to buyer(sender)
            TransferHelper.safeTransfer(pair.quote, sender, converted);
            // send deposited amount of quote asset from buyer to seller(owner)
            TransferHelper.safeTransfer(pair.base, order.owner, amount);
            // decrease remaining amount of order
            _decreaseOrder(isAsk, orderId, converted);
        }
        // if the order is bid order on the base/quote pair
        else {
            // sender is matching bid order for quote asset with base asset
            // send converted amount of quote asset from order to seller(owner)
            TransferHelper.safeTransfer(pair.quote, order.owner, amount);
            // send deposited amount of base asset from seller to buyer(sender)
            TransferHelper.safeTransfer(pair.base, sender, converted);
            // decrease remaining amount of order
            _decreaseOrder(isAsk, orderId, converted);
        }
        return order.owner;
    }

    function fpop(
        bool isAsk,
        uint256 price
    ) external returns (uint256 orderId) {
        require(msg.sender == pair.engine, "Only engine can dequeue");
        orderId = isAsk ? _fpop(true, price) : _fpop(false, price);
        if (isEmpty(isAsk, price)) {
            isAsk
                ? pHeads.askHead = _next(isAsk, price)
                : pHeads.bidHead = _next(isAsk, price);
        }
        return orderId;
    }

    function _absdiff(uint8 a, uint8 b) internal pure returns (uint8, bool) {
        return (a > b ? a - b : b - a, a > b);
    }

    // get required amount for executing the order
    function getRequired(
        bool isAsk,
        uint256 price,
        uint256 orderId
    ) external view returns (uint256 required) {
        IOrderbook2.Order memory order = isAsk
            ? _getOrder(true, orderId)
            : _getOrder(false, orderId);
        if (order.depositAmount == 0) {
            return 0;
        }
        /* if ask, required base amount is quoteAmount / price,
         * converting the number converting decimal from quote to base,
         * otherwise quote amount is baseAmount * price, converting decimal from base to quote
         */
        return _convert(price, order.depositAmount, isAsk);
    }

    /////////////////////////////////
    /// Price linked list methods ///
    /////////////////////////////////

    function heads() external view returns (uint256, uint256) {
        return _heads();
    }

    function bidHead() external view returns (uint256) {
        return _bidHead();
    }

    function askHead() external view returns (uint256) {
        return _askHead();
    }

    function mktPrice() external view returns (uint256) {
        return _mktPrice();
    }

    function getPrices(
        bool isAsk,
        uint256 n
    ) external view returns (uint256[] memory) {
        return isAsk ? _getPrices(true, n) : _getPrices(false, n);
    }

    function getOrderIds(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (uint256[] memory) {
        return
            isAsk
                ? _getOrderIds(true, price, n)
                : _getOrderIds(false, price, n);
    }

    function getOrders(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (IOrderbook2.Order[] memory) {
        return
            isAsk
                ? _getOrders(true, price, n)
                : _getOrders(false, price, n);
    }

    function getOrder(
        bool isAsk,
        uint256 orderId
    ) external view returns (IOrderbook2.Order memory) {
        return isAsk ? _getOrder(true, orderId) : _getOrder(false, orderId);
    }

    /**
     * @dev get asset value in quote asset if isAsk is true, otherwise get asset value in base asset
     * @param amount amount of asset in base asset if isAsk is true, otherwise in quote asset
     * @param isAsk if true, get asset value in quote asset, otherwise get asset value in base asset
     * @return converted asset value in quote asset if isAsk is true, otherwise asset value in base asset
     */
    function assetValue(
        uint256 amount,
        bool isAsk
    ) external view returns (uint256 converted) {
        return _convert(_mktPrice(), amount, isAsk);
    }

    function isEmpty(bool isAsk, uint256 price) public view returns (bool) {
        return isAsk ? _isEmpty(true, price) : _isEmpty(false, price);
    }

    function _convert(
        uint256 price,
        uint256 amount,
        bool isAsk
    ) internal view returns (uint256 converted) {
        if (isAsk) {
            // convert quote to base
            return baseBquote ? (amount * price) / 1e8 * decDiff  : (amount * price) / 1e8 / decDiff;
        } else {
            // convert base to quote
            return baseBquote ? (amount * 1e8) / price / decDiff : amount * 1e8 * decDiff / price ;
        }
    }
}
