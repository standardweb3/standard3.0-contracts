// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {IOrderbook} from "../interfaces/IOrderbook.sol";
import {Initializable} from "../../security/Initializable.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {ExchangeLinkedList} from "../libraries/ExchangeLinkedList.sol";
import {ExchangeOrderbook} from "../libraries/ExchangeOrderbook.sol";
import {IMatchingEngine} from "../interfaces/IMatchingEngine.sol";

interface IWETHMinimal {
    function WETH() external view returns (address);

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract Orderbook is IOrderbook, Initializable {
    using ExchangeLinkedList for ExchangeLinkedList.PriceLinkedList;
    using ExchangeOrderbook for ExchangeOrderbook.OrderStorage;

    uint32 public constant DENOM = 100000000;

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

    ExchangeLinkedList.PriceLinkedList private priceLists;
    ExchangeOrderbook.OrderStorage private _askOrders;
    ExchangeOrderbook.OrderStorage private _bidOrders;
    uint64 public tradeCount = 0;

    error InvalidDecimals(uint8 base, uint8 quote);
    error InvalidAccess(address sender, address allowed);
    error PriceIsZero(uint256 price);

    function _nextTradeId() internal view returns (uint64) {
        return tradeCount == 0 || tradeCount == type(uint64).max ? 1 : tradeCount + 1;
    }

    function initialize(uint256 id_, address base_, address quote_, address engine_) external initializer {
        uint8 baseD = TransferHelper.decimals(base_);
        uint8 quoteD = TransferHelper.decimals(quote_);
        if (baseD > 18 || quoteD > 18) {
            revert InvalidDecimals(baseD, quoteD);
        }
        (uint8 diff, bool baseBquote_) = _absdiff(baseD, quoteD);
        decDiff = uint64(10 ** diff);
        baseBquote = baseBquote_;
        pair = Pair(id_, base_, quote_, engine_);
    }

    modifier onlyEngine() {
        if (msg.sender != pair.engine) {
            revert InvalidAccess(msg.sender, pair.engine);
        }
        _;
    }

    function setLmp(uint256 price) external onlyEngine {
        if (price == 0) revert PriceIsZero(price);
        priceLists._setLmp(price);
    }

    function placeAsk(address owner, uint256 price, uint256 amount)
        external
        onlyEngine
        returns (uint32 id, bool foundDmt)
    {
        // clear empty head
        clearEmptyHead(false);
        (id, foundDmt) = _askOrders._createOrder(owner, price, amount);
        // check if the price is new in the list. if not, insert id to the list
        if (_askOrders._isEmpty(price)) {
            priceLists._insert(false, price);
        }
        _askOrders._insertId(price, id, amount);
        return (id, foundDmt);
    }

    function placeBid(address owner, uint256 price, uint256 amount)
        external
        onlyEngine
        returns (uint32 id, bool foundDmt)
    {
        // clear empty head
        clearEmptyHead(true);
        (id, foundDmt) = _bidOrders._createOrder(owner, price, amount);
        // check if the price is new in the list. if not, insert id to the list
        if (_bidOrders._isEmpty(price)) {
            priceLists._insert(true, price);
        }
        _bidOrders._insertId(price, id, amount);
        return (id, foundDmt);
    }

    function removeDmt(bool isBid) external onlyEngine returns (ExchangeOrderbook.Order memory order) {
        // get dormant order
        order = isBid ? _bidOrders.dormantOrder : _askOrders.dormantOrder;

        isBid
            ? _sendFunds(pair.quote, order.owner, order.depositAmount, false, false)
            : _sendFunds(pair.base, order.owner, order.depositAmount, false, false);

        // check if the dormant order was the only one order in the list of the price after deleting on order renewal
        if (isEmpty(isBid, order.price)) {
            priceLists._delete(isBid, order.price);
        }

        // free memory for dormant order
        isBid ? delete _bidOrders.dormantOrder : delete _askOrders.dormantOrder;
        return order;
    }

    function cancelOrder(bool isBid, uint32 orderId, address owner) external onlyEngine returns (uint256 remaining) {
        // check order owner
        ExchangeOrderbook.Order memory order = isBid ? _bidOrders._getOrder(orderId) : _askOrders._getOrder(orderId);

        // check before the price had an order not being empty
        bool wasEmpty = isEmpty(isBid, order.price);

        if (order.owner != owner) {
            revert InvalidAccess(owner, order.owner);
        }

        uint256 deletePrice = isBid ? _bidOrders._deleteOrder(orderId) : _askOrders._deleteOrder(orderId);
        isBid
            ? _sendFunds(pair.quote, owner, order.depositAmount, false, false)
            : _sendFunds(pair.base, owner, order.depositAmount, false, false);

        // check if the canceled order was the only one order in the list
        if (!wasEmpty && deletePrice != 0) {
            priceLists._delete(isBid, order.price);
        }

        return (order.depositAmount);
    }

    function execute(uint32 orderId, bool isBid, address sender, uint256 amount, bool clear)
        external
        onlyEngine
        returns (IMatchingEngine.OrderMatch memory orderMatch)
    {
        ExchangeOrderbook.Order memory order = isBid ? _bidOrders._getOrder(orderId) : _askOrders._getOrder(orderId);
        uint256 converted = convert(order.price, amount, isBid);
        uint256 dust = convert(order.price, 1, isBid);
        uint256 baseFee;
        uint256 quoteFee;
        // if isBid == true, sender is matching ask order with bid order(i.e. selling base to receive quote), otherwise sender is matching bid order with ask order(i.e. buying base with quote)
        if (isBid) {
            // decrease remaining amount of order
            (uint256 withDust, uint256 deletePrice) = _bidOrders._decreaseOrder(orderId, converted, dust, clear);
            // sender is matching ask order for base asset with quote asset
            baseFee = _sendFunds(pair.base, order.owner, amount, true, true);
            // send converted amount of quote asset from owner to sender
            quoteFee = _sendFunds(pair.quote, sender, withDust, true, false);
            // delete price if price of the order is empty
            if (deletePrice != 0) {
                priceLists._delete(isBid, deletePrice);
            }
        }
        // if the order is bid order on the base/quote pair
        else {
            // decrease remaining amount of order
            (uint256 withDust, uint256 deletePrice) = _askOrders._decreaseOrder(orderId, converted, dust, clear);
            // sender is matching bid order for quote asset with base asset
            // send deposited amount of quote asset from sender to owner
            quoteFee = _sendFunds(pair.quote, order.owner, amount, true, true);
            // send converted amount of base asset from owner to sender
            baseFee = _sendFunds(pair.base, sender, withDust, true, false);
            // delete price if price of the order is empty
            if (deletePrice != 0) {
                priceLists._delete(isBid, deletePrice);
            }
        }
        // add tradeId to make trade unique on the orderbook
        tradeCount = _nextTradeId();
        return IMatchingEngine.OrderMatch(order.owner, baseFee, quoteFee, tradeCount);
    }

    function clearEmptyHead(bool isBid) public returns (uint256 head) {
        head = isBid ? priceLists._bidHead() : priceLists._askHead();
        uint32 orderId = isBid ? _bidOrders._head(head) : _askOrders._head(head);
        while (orderId == 0 && head != 0) {
            orderId = isBid ? _bidOrders._head(head) : _askOrders._head(head);
            if (orderId == 0) {
                head = priceLists._clearHead(isBid);
            }
        }
        return head;
    }

    function fpop(bool isBid, uint256 price, uint256 remaining)
        external
        onlyEngine
        returns (uint32 orderId, uint256 required, bool clear)
    {
        orderId = isBid ? _bidOrders._head(price) : _askOrders._head(price);
        ExchangeOrderbook.Order memory order = isBid ? _bidOrders._getOrder(orderId) : _askOrders._getOrder(orderId);
        required = convert(price, order.depositAmount, !isBid);
        if (required <= remaining) {
            isBid ? _bidOrders._fpop(price) : _askOrders._fpop(price);
            if (isEmpty(isBid, price)) {
                isBid
                    ? priceLists.bidHead = priceLists._next(isBid, price)
                    : priceLists.askHead = priceLists._next(isBid, price);
            }
            return (orderId, required, true); // clear order as required <=remaining
        }
        return (orderId, required, false);
    }

    function _sendFunds(address token, address to, uint256 amount, bool applyFee, bool isMaker)
        internal
        returns (uint256 feeAmount)
    {
        address weth = IWETHMinimal(pair.engine).WETH();
        if (applyFee) {
            uint32 fee = IMatchingEngine(pair.engine).feeOf(pair.base, pair.quote, to, isMaker);
            feeAmount = (amount * fee) / DENOM;
            address feeTo = IMatchingEngine(pair.engine).feeTo();
            uint256 withoutFee = amount - feeAmount;
            if (token == weth) {
                IWETHMinimal(weth).withdraw(amount);
                payable(feeTo).transfer(feeAmount);
                payable(to).transfer(withoutFee);
            } else {
                TransferHelper.safeTransfer(token, feeTo, feeAmount);
                TransferHelper.safeTransfer(token, to, withoutFee);
            }
            return feeAmount;
        } else {
            if (token == weth) {
                IWETHMinimal(weth).withdraw(amount);
                payable(to).transfer(amount);
            } else {
                TransferHelper.safeTransfer(token, to, amount);
            }
            return 0;
        }
    }

    function _absdiff(uint8 a, uint8 b) internal pure returns (uint8, bool) {
        return (a > b ? a - b : b - a, a > b);
    }

    // get required amount for executing the order
    function getRequired(bool isBid, uint256 price, uint32 orderId) external view returns (uint256 required) {
        ExchangeOrderbook.Order memory order = isBid ? _bidOrders._getOrder(orderId) : _askOrders._getOrder(orderId);
        if (order.depositAmount == 0) {
            return 0;
        }
        /* if ask, required base amount is quoteAmount / price,
         * converting the number converting decimal from quote to base,
         * otherwise quote amount is baseAmount * price, converting decimal from base to quote
         */
        return convert(price, order.depositAmount, isBid);
    }

    /////////////////////////////////
    /// Price linked list methods ///
    /////////////////////////////////

    // last market price
    function lmp() external view returns (uint256) {
        return priceLists.lmp;
    }

    function heads() external view returns (uint256, uint256) {
        return priceLists._heads();
    }

    function askHead() external view returns (uint256) {
        return priceLists._askHead();
    }

    function bidHead() external view returns (uint256) {
        return priceLists._bidHead();
    }

    function orderHead(bool isBid, uint256 price) external view returns (uint32) {
        return isBid ? _bidOrders._head(price) : _askOrders._head(price);
    }

    function mktPrice() external view returns (uint256) {
        return priceLists._mktPrice();
    }

    function getPrices(bool isBid, uint32 n) external view returns (uint256[] memory) {
        return priceLists._getPrices(isBid, n);
    }

    function nextPrice(bool isBid, uint256 price) external view returns (uint256 next) {
        return priceLists._next(isBid, price);
    }

    function nextOrder(bool isBid, uint256 price, uint32 orderId) public view returns (uint32 next) {
        return isBid ? _bidOrders._next(price, orderId) : _askOrders._next(price, orderId);
    }

    function sfpop(bool isBid, uint256 price, uint32 orderId, bool isHead)
        external
        view
        returns (uint32 id, uint256 required, bool clear)
    {
        id = isHead ? orderId : nextOrder(isBid, price, orderId);
        ExchangeOrderbook.Order memory order = isBid ? _bidOrders._getOrder(id) : _askOrders._getOrder(id);
        required = convert(price, order.depositAmount, !isBid);
        return (id, required, id == 0);
    }

    function getPricesPaginated(bool isBid, uint32 start, uint32 end) external view returns (uint256[] memory) {
        return priceLists._getPricesPaginated(isBid, start, end);
    }

    function getOrderIds(bool isBid, uint256 price, uint32 n) external view returns (uint32[] memory) {
        return isBid ? _bidOrders._getOrderIds(price, n) : _askOrders._getOrderIds(price, n);
    }

    function getOrders(bool isBid, uint256 price, uint32 n) external view returns (ExchangeOrderbook.Order[] memory) {
        return isBid ? _bidOrders._getOrders(price, n) : _askOrders._getOrders(price, n);
    }

    function getOrdersPaginated(bool isBid, uint256 price, uint32 start, uint32 end)
        external
        view
        returns (ExchangeOrderbook.Order[] memory)
    {
        return isBid
            ? _bidOrders._getOrdersPaginated(price, start, end)
            : _askOrders._getOrdersPaginated(price, start, end);
    }

    function getOrder(bool isBid, uint32 orderId) external view returns (ExchangeOrderbook.Order memory) {
        return isBid ? _bidOrders._getOrder(orderId) : _askOrders._getOrder(orderId);
    }

    function getBaseQuote() external view returns (address base, address quote) {
        return (pair.base, pair.quote);
    }

    /**
     * @dev get asset value in quote asset if isBid is true, otherwise get asset value in base asset
     * @param amount amount of asset in base asset if isBid is true, otherwise in quote asset
     * @param isBid if true, get asset value in quote asset, otherwise get asset value in base asset
     * @return converted asset value in quote asset if isBid is true, otherwise asset value in base asset
     */
    function assetValue(uint256 amount, bool isBid) external view returns (uint256 converted) {
        return convert(priceLists._mktPrice(), amount, isBid);
    }

    function isEmpty(bool isBid, uint256 price) public view returns (bool) {
        return isBid ? _bidOrders._isEmpty(price) : _askOrders._isEmpty(price);
    }

    function convertMarket(uint256 amount, bool isBid) external view returns (uint256 converted) {
        return convert(priceLists.lmp, amount, isBid);
    }

    function convert(uint256 price, uint256 amount, bool isBid) public view returns (uint256 converted) {
        if (isBid) {
            // convert base to quote
            return baseBquote ? ((amount * price) / 1e8) / decDiff : ((amount * price) / 1e8) * decDiff;
        } else {
            // convert quote to base
            return baseBquote ? ((amount * 1e8) / price) * decDiff : ((amount * 1e8) / price) / decDiff;
        }
    }

    function nextMakeId(bool isBid) external view returns (uint32) {
        return isBid ? _bidOrders._nextMakeId() : _askOrders._nextMakeId();
    }

    receive() external payable {}
}
