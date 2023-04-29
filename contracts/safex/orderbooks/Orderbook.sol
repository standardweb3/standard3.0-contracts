// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "../interfaces/IOrderbook.sol";
import "../../security/Initializable.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/NewOrderLinkedList.sol";
import "../libraries/NewOrderOrderbook.sol";

contract Orderbook is IOrderbook, Initializable {
    using NewOrderLinkedList for NewOrderLinkedList.PriceLinkedList;
    using NewOrderOrderbook for NewOrderOrderbook.OrderStorage;

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

    //uint32 private constant PRICEONE = 1e8;

    // Reuse order storage with NewOrderLinkedList with isAsk always true
    NewOrderLinkedList.PriceLinkedList private priceLists;
    NewOrderOrderbook.OrderStorage private _bidOrders;
    NewOrderOrderbook.OrderStorage private _askOrders;

    function initialize(
        uint256 id_,
        address base_,
        address quote_,
        address engine_
    ) external initializer {
        uint8 baseD = TransferHelper.decimals(base_);
        uint8 quoteD = TransferHelper.decimals(quote_);
        require(baseD > 0 && quoteD > 0, "DECIMALS");
        (uint8 diff, bool baseBquote_) = _absdiff(baseD, quoteD);
        decDiff = uint64(10**diff);
        baseBquote = baseBquote_;
        pair = Pair(id_, base_, quote_, engine_);
    }

    function setLmp(uint256 price) external {
        require(msg.sender == pair.engine, "IA");
        priceLists._setLmp(price);
    }

    function placeBid(address owner, uint256 price, uint256 amount) external {
        require(msg.sender == pair.engine, "IA");
        uint256 id = _bidOrders._createOrder(owner, amount);
        priceLists._insert(false, price);
        _bidOrders._insertId(price, id, amount);
    }

    function placeAsk(address owner, uint256 price, uint256 amount) external {
        require(msg.sender == pair.engine, "IA");
        uint256 id = _askOrders._createOrder(owner, amount);
        priceLists._insert(true, price);
        _askOrders._insertId(price, id, amount);
    }

    function cancelOrder(
        uint256 orderId,
        bool isAsk,
        address owner
    ) external returns (uint256 remaining, address base, address quote) {
        require(msg.sender == pair.engine, "IA");
        NewOrderOrderbook.Order memory order = isAsk
            ? _askOrders._getOrder(orderId)
            : _bidOrders._getOrder(orderId);
        require(order.owner == owner, "NOT_OWNER");
        isAsk
            ? _askOrders._deleteOrder(orderId)
            : _bidOrders._deleteOrder(orderId);
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
        NewOrderOrderbook.Order memory order = isAsk
            ? _askOrders._getOrder(orderId)
            : _bidOrders._getOrder(orderId);
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
            _askOrders._decreaseOrder(orderId, converted);
        }
        // if the order is bid order on the base/quote pair
        else {
            // sender is matching bid order for quote asset with base asset
            // send converted amount of quote asset from order to seller(owner)
            TransferHelper.safeTransfer(pair.quote, order.owner, amount);
            // send deposited amount of base asset from seller to buyer(sender)
            TransferHelper.safeTransfer(pair.base, sender, converted);
            // decrease remaining amount of order
            _bidOrders._decreaseOrder(orderId, converted);
        }
        return order.owner;
    }

    function fpop(
        bool isAsk,
        uint256 price
    ) external returns (uint256 orderId) {
        require(msg.sender == pair.engine, "Only engine can dequeue");
        orderId = isAsk ? _askOrders._fpop(price) : _bidOrders._fpop(price);
        if (isEmpty(isAsk, price)) {
            isAsk
                ? priceLists.askHead = priceLists._next(isAsk, price)
                : priceLists.bidHead = priceLists._next(isAsk, price);
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
        NewOrderOrderbook.Order memory order = isAsk
            ? _askOrders._getOrder(orderId)
            : _bidOrders._getOrder(orderId);
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
        return priceLists._heads();
    }

    function bidHead() external view returns (uint256) {
        return priceLists._bidHead();
    }

    function askHead() external view returns (uint256) {
        return priceLists._askHead();
    }

    function mktPrice() external view returns (uint256) {
        return priceLists._mktPrice();
    }

    function getPrices(
        bool isAsk,
        uint256 n
    ) external view returns (uint256[] memory) {
        return isAsk ? _askOrders._getPrices(n) : _bidOrders._getPrices(n);
    }

    function getOrderIds(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (uint256[] memory) {
        return
            isAsk
                ? _askOrders._getOrderIds(price, n)
                : _bidOrders._getOrderIds(price, n);
    }

    function getOrders(
        bool isAsk,
        uint256 price,
        uint256 n
    ) external view returns (NewOrderOrderbook.Order[] memory) {
        return
            isAsk
                ? _askOrders._getOrders(price, n)
                : _bidOrders._getOrders(price, n);
    }

    function getOrder(
        bool isAsk,
        uint256 orderId
    ) external view returns (NewOrderOrderbook.Order memory) {
        return isAsk ? _askOrders._getOrder(orderId) : _bidOrders._getOrder(orderId);
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
        return _convert(priceLists._mktPrice(), amount, isAsk);
    }

    function isEmpty(bool isAsk, uint256 price) public view returns (bool) {
        return isAsk ? _askOrders._isEmpty(price) : _bidOrders._isEmpty(price);
    }

    function _convert(
        uint256 price,
        uint256 amount,
        bool isAsk
    ) internal view returns (uint256 converted) {
        if (isAsk) {
            // convert quote to base
            return baseBquote ? amount * price / 1e8 * decDiff  : amount * price / 1e8 / decDiff;
        } else {
            // convert base to quote
            return baseBquote ? amount * 1e8 / price / decDiff : amount * 1e8 * decDiff / price ;
        }
    }
}
