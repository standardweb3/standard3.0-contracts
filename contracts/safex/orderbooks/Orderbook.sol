// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IOrderbook} from "../interfaces/IOrderbook.sol";
import {Initializable} from "../../security/Initializable.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";
import {SAFEXLinkedList} from "../libraries/SAFEXLinkedList.sol";
import {SAFEXOrderbook} from "../libraries/SAFEXOrderbook.sol";

contract Orderbook is IOrderbook, Initializable {
    using SAFEXLinkedList for SAFEXLinkedList.PriceLinkedList;
    using SAFEXOrderbook for SAFEXOrderbook.OrderStorage;

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

    event OrderPlaced(address base, address quote, bool isBid, uint256 orderId);

    //uint32 private constant PRICEONE = 1e8;

    // Reuse order storage with SAFEXLinkedList with isBid always true
    SAFEXLinkedList.PriceLinkedList private priceLists;
    SAFEXOrderbook.OrderStorage private _askOrders;
    SAFEXOrderbook.OrderStorage private _bidOrders;

    error InvalidDecimals(uint8 base, uint8 quote);
    error InvalidAccess(address sender, address allowed);
    error OrderSizeTooSmall(uint256 amount, uint256 minRequired);

    function initialize(
        uint256 id_,
        address base_,
        address quote_,
        address engine_
    ) external initializer {
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
        priceLists._setLmp(price);
    }

    function placeAsk(
        address owner,
        uint256 price,
        uint256 amount
    ) external onlyEngine {
        uint256 id = _askOrders._createOrder(owner, amount);
        // check if the price is new in the list. if not, insert id to the list
        if (_askOrders._isEmpty(price)) {
            priceLists._insert(false, price);
        }
        _askOrders._insertId(price, id, amount);
        emit OrderPlaced(pair.base, pair.quote, false, id);
    }

    function placeBid(
        address owner,
        uint256 price,
        uint256 amount
    ) external onlyEngine {
        uint256 id = _bidOrders._createOrder(owner, amount);
        // check if the price is new in the list. if not, insert id to the list
        if (_bidOrders._isEmpty(price)) {
            priceLists._insert(true, price);
        }
        _bidOrders._insertId(price, id, amount);
        emit OrderPlaced(pair.base, pair.quote, true, id);
    }

    function cancelOrder(
        bool isBid,
        uint256 price,
        uint256 orderId,
        address owner
    )
        external
        onlyEngine
        returns (uint256 remaining, address base, address quote)
    {
        SAFEXOrderbook.Order memory order = isBid
            ? _bidOrders._getOrder(orderId)
            : _askOrders._getOrder(orderId);
        if (order.owner != owner) {
            revert InvalidAccess(owner, order.owner);
        }
        isBid
            ? _bidOrders._deleteOrder(price, orderId)
            : _askOrders._deleteOrder(price, orderId);
        isBid
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
        bool isBid,
        uint256 price,
        address sender,
        uint256 amount
    ) external onlyEngine returns (address owner) {
        SAFEXOrderbook.Order memory order = isBid
            ? _bidOrders._getOrder(orderId)
            : _askOrders._getOrder(orderId);
        /* if ask, converted quote amount is baseAmount * price,
         * converting the number converting decimal from base to quote,
         * otherwise quote amount is baseAmount / price, converting decimal from quote to base
         */
        uint256 converted = _convert(price, amount, !isBid);
        if (converted == 0) {
            revert OrderSizeTooSmall(amount, _convert(price, 1, isBid));
        }
        // if the order is ask order on the base/quote pair
        if (isBid) {
            // sender is matching ask order for base asset with quote asset
            // send converted amount of base asset from order to buyer(sender)
            TransferHelper.safeTransfer(pair.quote, sender, converted);
            // send deposited amount of quote asset from buyer to seller(owner)
            TransferHelper.safeTransfer(pair.base, order.owner, amount);
            // decrease remaining amount of order
            _bidOrders._decreaseOrder(price, orderId, converted);
        }
        // if the order is bid order on the base/quote pair
        else {
            // sender is matching bid order for quote asset with base asset
            // send converted amount of quote asset from order to seller(owner)
            TransferHelper.safeTransfer(pair.quote, order.owner, amount);
            // send deposited amount of base asset from seller to buyer(sender)
            TransferHelper.safeTransfer(pair.base, sender, converted);
            // decrease remaining amount of order
            _askOrders._decreaseOrder(price, orderId, converted);
        }
        return order.owner;
    }

    function fpop(
        bool isBid,
        uint256 price,
        uint256 remaining
    ) external onlyEngine returns (uint256 orderId, uint256 required) {
        orderId = isBid ? _bidOrders._head(price) : _askOrders._head(price);
        SAFEXOrderbook.Order memory order = isBid
            ? _bidOrders._getOrder(orderId)
            : _askOrders._getOrder(orderId);
        required = _convert(price, order.depositAmount, isBid);
        if (required <= remaining) {
            isBid ? _bidOrders._fpop(price) : _askOrders._fpop(price);
            if (isEmpty(isBid, price)) {
                isBid
                    ? priceLists.bidHead = priceLists._next(isBid, price)
                    : priceLists.askHead = priceLists._next(isBid, price);
            }
        }
        return (orderId, required);
    }

    function _absdiff(uint8 a, uint8 b) internal pure returns (uint8, bool) {
        return (a > b ? a - b : b - a, a > b);
    }

    // get required amount for executing the order
    function getRequired(
        bool isBid,
        uint256 price,
        uint256 orderId
    ) external view returns (uint256 required) {
        SAFEXOrderbook.Order memory order = isBid
            ? _bidOrders._getOrder(orderId)
            : _askOrders._getOrder(orderId);
        if (order.depositAmount == 0) {
            return 0;
        }
        /* if ask, required base amount is quoteAmount / price,
         * converting the number converting decimal from quote to base,
         * otherwise quote amount is baseAmount * price, converting decimal from base to quote
         */
        return _convert(price, order.depositAmount, isBid);
    }

    /////////////////////////////////
    /// Price linked list methods ///
    /////////////////////////////////

    function heads() external view returns (uint256, uint256) {
        return priceLists._heads();
    }

    function askHead() external view returns (uint256) {
        return priceLists._askHead();
    }

    function bidHead() external view returns (uint256) {
        return priceLists._bidHead();
    }

    function mktPrice() external view returns (uint256) {
        return priceLists._mktPrice();
    }

    function getPrices(
        bool isBid,
        uint256 n
    ) external view returns (uint256[] memory) {
        return priceLists._getPrices(isBid, n);
    }

    function getOrderIds(
        bool isBid,
        uint256 price,
        uint256 n
    ) external view returns (uint256[] memory) {
        return
            isBid
                ? _bidOrders._getOrderIds(price, n)
                : _askOrders._getOrderIds(price, n);
    }

    function getOrders(
        bool isBid,
        uint256 price,
        uint256 n
    ) external view returns (SAFEXOrderbook.Order[] memory) {
        return
            isBid
                ? _bidOrders._getOrders(price, n)
                : _askOrders._getOrders(price, n);
    }

    function getOrder(
        bool isBid,
        uint256 orderId
    ) external view returns (SAFEXOrderbook.Order memory) {
        return
            isBid
                ? _bidOrders._getOrder(orderId)
                : _askOrders._getOrder(orderId);
    }

    /**
     * @dev get asset value in quote asset if isBid is true, otherwise get asset value in base asset
     * @param amount amount of asset in base asset if isBid is true, otherwise in quote asset
     * @param isBid if true, get asset value in quote asset, otherwise get asset value in base asset
     * @return converted asset value in quote asset if isBid is true, otherwise asset value in base asset
     */
    function assetValue(
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted) {
        return _convert(priceLists._mktPrice(), amount, isBid);
    }

    function isEmpty(bool isBid, uint256 price) public view returns (bool) {
        return isBid ? _bidOrders._isEmpty(price) : _askOrders._isEmpty(price);
    }

    function _convert(
        uint256 price,
        uint256 amount,
        bool isBid
    ) internal view returns (uint256 converted) {
        if (!isBid) {
            // convert quote to base
            return
                baseBquote
                    ? ((amount * price) / 1e8) * decDiff
                    : (amount * price) / 1e8 / decDiff;
        } else {
            // convert base to quote
            return
                baseBquote
                    ? (amount * 1e8) / price / decDiff
                    : (amount * 1e8 * decDiff) / price;
        }
    }
}
