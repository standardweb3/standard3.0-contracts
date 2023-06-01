// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOrderbookFactory.sol";
import "./interfaces/IOrderbook.sol";
import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IRevenue {
    function report(
        uint32 uid,
        address token,
        uint256 amount,
        bool isAdd
    ) external;

    function isReportable(
        address token,
        uint32 uid
    ) external view returns (bool);

    function refundFee(address to, address token, uint256 amount) external;
}

// Onchain Matching engine for the orders
contract MatchingEngine is AccessControl, Initializable, UUPSUpgradeable {
    // roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // fee recipient
    address private feeTo;
    // fee denominator
    uint256 public feeDenom;
    // fee numerator
    uint256 public feeNum;
    // Factories
    address public orderbookFactory;
    // Fee token
    address public lFeeToken;
    // Fee amount
    uint256 public lFeeAmount;
    // membership contract
    address public membership;
    // accountant contract
    address public accountant;

    // events
    event OrderCanceled(
        address orderbook,
        uint256 id,
        bool isBid,
        address owner
    );

    event OrderMatched(
        address orderbook,
        uint256 id,
        bool isBid,
        address sender,
        address owner,
        uint256 amount,
        uint256 price
    );

    event PairAdded(address orderbook, address base, address quote);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeTo = msg.sender;
        feeDenom = 1000;
        feeNum = 3;
    }

    /**
     * @dev Initialize the matching engine with orderbook factory and listing requirements.
     * It can be called only once.
     * @param orderbookFactory_ address of orderbook factory
     * @param feeToken_ address of listing fee token
     * @param feeAmountOne_ listing fee token amount in 1e18
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function initialize(
        address orderbookFactory_,
        address feeToken_,
        uint256 feeAmountOne_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) initializer {
        orderbookFactory = orderbookFactory_;
        lFeeToken = feeToken_;
        lFeeAmount = feeAmountOne_ * 1e18;
    }

    /**
     * @dev Set listing requirements.
     * @param feeToken_ address of listing fee token
     * @param feeAmountOne_ listing fee token amount in 1e18
     */
    function setListingFee(
        address feeToken_,
        uint256 feeAmountOne_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        lFeeToken = feeToken_;
        lFeeAmount = feeAmountOne_ * 1e18;
    }

    /**
     * @dev Set orderbook factory address.
     * @param orderbookFactory_ address of orderbook factory
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function setOrderbookFactory(
        address orderbookFactory_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        orderbookFactory = orderbookFactory_;
    }

    function setMembership(
        address membership_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        membership = membership_;
    }

    function setAccountant(
        address accountant_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        accountant = accountant_;
    }

    error InvalidFeeRate(uint256 feeNum, uint256 feeDenom);

    /**
     * @dev Set the fee numerator and denominator of trading.
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function setFee(
        uint256 feeNum_,
        uint256 feeDenom_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // check if fee numerator and denominator are valid
        if (feeNum >= 1e8 || feeDenom >= 1e8 || feeNum_ >= feeDenom_) {
            revert InvalidFeeRate(feeNum_, feeDenom_);
        }
        feeNum = feeNum_;
        feeDenom = feeDenom_;
    }

    /**
     * @dev Set the fee recipient.
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function setFeeTo(address feeTo_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeTo = feeTo_;
    }

    /**
     * @dev Executes a market buy order,
     * buys the base asset using the quote asset at the best available price in the orderbook up to `n` orders,
     * and places a stop order at the market price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of quote asset to be used for the market buy order
     * @param isStop Boolean indicating if a stop order should be placed at the market price
     * @param n The maximum number of orders to match in the orderbook
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function marketBuy(
        address base,
        address quote,
        uint256 amount,
        bool isStop,
        uint32 n,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            true,
            uid
        );
        // negate on give if the asset is not the base
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            quote,
            true,
            type(uint256).max,
            n
        );
        // add stop order on market price
        _detStop(
            orderbook,
            quote,
            remaining,
            mktPrice(base, quote),
            true,
            isStop
        );
        return true;
    }

    /**
     * @dev Executes a market sell order,
     * sells the base asset for the quote asset at the best available price in the orderbook up to `n` orders,
     * and places a stop order at the market price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of base asset to be sold in the market sell order
     * @param isStop Boolean indicating if a stop order should be placed at the market price
     * @param n The maximum number of orders to match in the orderbook
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function marketSell(
        address base,
        address quote,
        uint256 amount,
        bool isStop,
        uint32 n,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false,
            uid
        );
        // negate on give if the asset is not the base
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            base,
            false,
            type(uint256).max,
            n
        );
        _detStop(
            orderbook,
            base,
            remaining,
            mktPrice(base, quote),
            false,
            isStop
        );
        return true;
    }

    /**
     * @dev Executes a limit buy order,
     * places a limit order in the orderbook for buying the base asset using the quote asset at a specified price,
     * and places a stop order at the limit price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of quote asset to be used for the limit buy order
     * @param at The price at which the limit buy order should be placed
     * @param isStop Boolean indicating if a stop order should be placed at the limit price
     * @param n The maximum number of orders to match in the orderbook
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function limitBuy(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        bool isStop,
        uint32 n,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            true,
            uid
        );
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            quote,
            true,
            at,
            n
        );

        _detStop(orderbook, quote, remaining, at, true, isStop);
        return true;
    }

    /**
     * @dev Executes a limit sell order,
     * places a limit order in the orderbook for selling the base asset for the quote asset at a specified price,
     * and places a stop order at the limit price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of base asset to be used for the limit sell order
     * @param at The price at which the limit sell order should be placed
     * @param isStop Boolean indicating if a stop order should be placed at the limit price
     * @param n The maximum number of orders to match in the orderbook
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function limitSell(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        bool isStop,
        uint32 n,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false,
            uid
        );
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            base,
            false,
            at,
            n
        );
        _detStop(orderbook, base, remaining, at, false, isStop);
        return true;
    }

    /**
     * @dev Places a stop buy order in the orderbook for the base asset using the quote asset,
     * with a specified price `at`.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of quote asset to be used for the stop buy order
     * @param at The price at which the stop buy order will be executed
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function stopBuy(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false,
            uid
        );
        TransferHelper.safeTransfer(quote, orderbook, withoutFee);
        _stopOrder(orderbook, withoutFee, at, true);
        return true;
    }

    /**
     * @dev Places a stop sell order in the orderbook for the quote asset using the base asset,
     * with a specified price `at`.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param amount The amount of base asset to be used for the stop sell order
     * @param at The price at which the stop sell order will be executed
     * @return bool True if the order was successfully executed, otherwise false.
     */
    function stopSell(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        uint32 uid
    ) external returns (bool) {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false,
            uid
        );
        TransferHelper.safeTransfer(base, orderbook, withoutFee);
        _stopOrder(orderbook, withoutFee, at, false);
        return true;
    }

    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @return book The address of the newly created orderbook
     */
    function addPair(
        address base,
        address quote
    ) external returns (address book) {
        TransferHelper.safeTransferFrom(
            lFeeToken,
            msg.sender,
            address(this),
            lFeeAmount
        );
        TransferHelper.safeTransfer(lFeeToken, feeTo, lFeeAmount);
        // create orderbook for the pair
        address orderBook = IOrderbookFactory(orderbookFactory).createBook(
            base,
            quote,
            address(this)
        );
        emit PairAdded(orderBook, base, quote);
        return orderBook;
    }

    /**
     * @dev Cancels an order in an orderbook by the given order ID and order type.
     * @param orderbook The address of the orderbook to cancel the order in
     * @param orderId The ID of the order to cancel
     * @param isBid Boolean indicating if the order to cancel is an ask order
     * @return bool True if the order was successfully canceled, otherwise false.
     */
    function cancelOrder(
        address orderbook,
        uint256 orderId,
        bool isBid,
        uint32 uid
    ) external returns (bool) {
        (uint256 remaining, address base, address quote) = IOrderbook(orderbook)
            .cancelOrder(orderId, isBid, msg.sender);
        // decrease point from orderbook
        if (uid != 0 && IRevenue(membership).isReportable(msg.sender, uid)) {
            // report cancelation to accountant
            IRevenue(accountant).report(
                uid,
                isBid ? quote : base,
                remaining,
                false
            );
        }
        // refund fee from treasury to sender
        IRevenue(feeTo).refundFee(
            msg.sender,
            isBid ? quote : base,
            (remaining * feeNum) / feeDenom
        );

        emit OrderCanceled(orderbook, orderId, isBid, msg.sender);
        return true;
    }

    /**
     * @dev Returns the address of the orderbook with the given ID.
     * @param id The ID of the orderbook to retrieve.
     * @return The address of the orderbook.
     */
    function getOrderbookById(uint256 id) external view returns (address) {
        return IOrderbookFactory(orderbookFactory).getBook(id);
    }

    /**
     * @dev Returns the base and quote asset addresses for the given orderbook.
     * @param orderbook The address of the orderbook to retrieve the base and quote asset addresses for.
     * @return base The address of the base asset.
     * @return quote The address of the quote asset.
     */
    function getBaseQuote(
        address orderbook
    ) external view returns (address base, address quote) {
        return IOrderbookFactory(orderbookFactory).getBaseQuote(orderbook);
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return pairs list of pairs from start to end
     */
    function getPairs(
        uint start,
        uint end
    ) external view returns (IOrderbookFactory.Pair[] memory pairs) {
        return IOrderbookFactory(orderbookFactory).getPairs(start, end);
    }

    /**
     * @dev Returns prices in the ask/bid orderbook for the given trading pair.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve prices from is an ask orderbook.
     * @param n The number of prices to retrieve.
     */
    function getPrices(
        address base,
        address quote,
        bool isBid,
        uint256 n
    ) external view returns (uint256[] memory) {
        address orderbook = getBookByPair(base, quote);
        return IOrderbook(orderbook).getPrices(isBid, n);
    }

    /**
     * @dev Returns orders in the ask/bid orderbook for the given trading pair in a price.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve orders from is an ask orderbook.
     * @param price The price to retrieve orders from.
     * @param n The number of orders to retrieve.
     */
    function getOrders(
        address base,
        address quote,
        bool isBid,
        uint256 price,
        uint256 n
    ) external view returns (NewOrderOrderbook.Order[] memory) {
        address orderbook = getBookByPair(base, quote);
        return IOrderbook(orderbook).getOrders(isBid, price, n);
    }

    /**
     * @dev Returns an order in the ask/bid orderbook for the given trading pair with order id.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve orders from is an ask orderbook.
     * @param orderId The order id to retrieve.
     */
    function getOrder(
        address base,
        address quote,
        bool isBid,
        uint256 orderId
    ) external view returns (NewOrderOrderbook.Order memory) {
        address orderbook = getBookByPair(base, quote);
        return IOrderbook(orderbook).getOrder(isBid, orderId);
    }

    /**
     * @dev Returns order ids in the ask/bid orderbook for the given trading pair in a price.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve orders from is an ask orderbook.
     * @param price The price to retrieve orders from.
     * @param n The number of order ids to retrieve.
     */
    function getOrderIds(
        address base,
        address quote,
        bool isBid,
        uint256 price,
        uint256 n
    ) external view returns (uint256[] memory) {
        address orderbook = getBookByPair(base, quote);
        return IOrderbook(orderbook).getOrderIds(isBid, price, n);
    }

    /**
     * @dev Returns the address of the orderbook for the given base and quote asset addresses.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @return book The address of the orderbook.
     */
    function getBookByPair(
        address base,
        address quote
    ) public view returns (address book) {
        return IOrderbookFactory(orderbookFactory).getBookByPair(base, quote);
    }

    function mktPrice(
        address base,
        address quote
    ) public view returns (uint256) {
        address orderbook = getBookByPair(base, quote);
        return IOrderbook(orderbook).mktPrice();
    }

    /**
     * @dev return converted amount from base to quote or vice versa
     * @param base address of base asset
     * @param quote address of quote asset
     * @param amount amount of base or quote asset
     * @param isBid if true, amount is quote asset, otherwise base asset
     * @return converted converted amount from base to quote or vice versa.
     * if true, amount is quote asset, otherwise base asset
     * if orderbook does not exist, return 0
     */
    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted) {
        address orderbook = getBookByPair(base, quote);
        if (base == quote) {
            return amount;
        } else if (orderbook == address(0)) {
            return 0;
        } else {
            return IOrderbook(orderbook).assetValue(amount, isBid);
        }
    }

    /**
     * @dev Internal function which places a stop order on the orderbook.
     * @param orderbook The address of the orderbook contract for the trading pair
     * @param withoutFee The remaining amount of the asset after the market order has been executed
     * @param at The stop price of the order
     * @param isBid Boolean indicating if the order is a buy (false) or a sell (true)
     */
    function _stopOrder(
        address orderbook,
        uint256 withoutFee,
        uint256 at,
        bool isBid
    ) internal {
        // create order
        if (isBid) {
            IOrderbook(orderbook).placeBid(msg.sender, at, withoutFee);
        } else {
            IOrderbook(orderbook).placeAsk(msg.sender, at, withoutFee);
        }
    }

    error TooManyMatches(uint256 n);

    /**
     * @dev Match bid if `isBid` is true, match ask if `isBid` is false.
     */
    function _matchAt(
        address orderbook,
        address give,
        bool isBid,
        uint256 amount,
        uint256 priceAt,
        uint32 i,
        uint32 n
    ) internal returns (uint256 remaining, uint32 k) {
        if (n >= 10) {
            revert TooManyMatches(n);
        }
        remaining = amount;
        while (
            remaining > 0 &&
            !IOrderbook(orderbook).isEmpty(!isBid, priceAt) &&
            i < n
        ) {
            // fpop OrderLinkedList by price, if ask you get bid order, if bid you get ask order
            uint256 orderId = IOrderbook(orderbook).fpop(!isBid, priceAt);
            // Get quote asset on bid order on buy, base asset on ask order on sell
            uint256 required = IOrderbook(orderbook).getRequired(
                !isBid,
                priceAt,
                orderId
            );
            // order exists, and amount is not 0
            if (remaining <= required) {
                TransferHelper.safeTransfer(give, orderbook, remaining);
                address owner = IOrderbook(orderbook).execute(
                    orderId,
                    !isBid,
                    priceAt,
                    msg.sender,
                    remaining
                );
                // emit event order matched
                emit OrderMatched(
                    orderbook,
                    orderId,
                    isBid,
                    msg.sender,
                    owner,
                    remaining,
                    priceAt
                );
                // set last match price
                // end loop as remaining is 0
                return (0, n);
            }
            // order is null
            else if (required == 0) {
                continue;
            }
            // remaining >= depositAmount
            else {
                remaining -= required;
                TransferHelper.safeTransfer(give, orderbook, required);
                address owner = IOrderbook(orderbook).execute(
                    orderId,
                    !isBid,
                    priceAt,
                    msg.sender,
                    required
                );
                // emit event order matched
                emit OrderMatched(
                    orderbook,
                    orderId,
                    isBid,
                    msg.sender,
                    owner,
                    required,
                    priceAt
                );
                ++i;
            }
        }
        k = i;
        return (remaining, k);
    }

    /**
     * @dev Executes limit order by matching orders in the orderbook based on the provided limit price.
     * @param orderbook The address of the orderbook to execute the limit order on.
     * @param amount The amount of asset to trade.
     * @param give The address of the asset to be traded.
     * @param isBid True if the order is an ask (sell) order, false if it is a bid (buy) order.
     * @param limitPrice The maximum price at which the order can be executed.
     * @param n The maximum number of matches to execute.
     * @return remaining The remaining amount of asset that was not traded.
     */
    function _limitOrder(
        address orderbook,
        uint256 amount,
        address give,
        bool isBid,
        uint256 limitPrice,
        uint32 n
    ) internal returns (uint256 remaining) {
        remaining = amount;
        uint256 lmp = 0;
        uint32 i = 0;
        if (isBid) {
            // check if there is any matching bid order until matching bid order price is higher than the limit Price
            uint256 askHead = IOrderbook(orderbook).askHead();
            while (
                remaining > 0 && askHead != 0 && askHead <= limitPrice && i < n
            ) {
                lmp = askHead;
                (remaining, i) = _matchAt(
                    orderbook,
                    give,
                    isBid,
                    remaining,
                    askHead,
                    i,
                    n
                );
                askHead = IOrderbook(orderbook).askHead();
            }
        } else {
            // check if there is any maching ask order until matching ask order price is lower than the limit price
            uint bidHead = IOrderbook(orderbook).bidHead();
            while (
                remaining > 0 && bidHead != 0 && bidHead >= limitPrice && i < n
            ) {
                lmp = bidHead;
                (remaining, i) = _matchAt(
                    orderbook,
                    give,
                    isBid,
                    remaining,
                    bidHead,
                    i,
                    n
                );
                bidHead = IOrderbook(orderbook).bidHead();
            }
        }
        // set last match price
        if (lmp != 0) {
            IOrderbook(orderbook).setLmp(lmp);
        }
        return (remaining);
    }

    /**
     * @dev Determines if a stop order should be placed at the market price,
     * and if so, places the stop order on the orderbook.
     * If no stop order should be placed, transfers the remaining asset to either the orderbook or the user.
     * @param orderbook The address of the orderbook contract for the trading pair
     * @param asset The address of the asset to be transferred as the stop order
     * @param remaining The remaining amount of the asset after the market order has been executed
     * @param price The market price used to determine if a stop order should be placed
     * @param isBid Boolean indicating if the market order was a buy (true) or a sell (false)
     * @param isStop Boolean indicating if a stop order should be placed at the market price
     */
    function _detStop(
        address orderbook,
        address asset,
        uint256 remaining,
        uint256 price,
        bool isBid,
        bool isStop
    ) internal {
        if (remaining > 0) {
            address stopTo = isStop ? orderbook : msg.sender;
            TransferHelper.safeTransfer(asset, stopTo, remaining);
            if (isStop) _stopOrder(orderbook, remaining, price, isBid);
        }
    }

    /**
     * @dev Deposit amount of asset to the contract with the given asset information and subtracts the fee.
     * @param base The address of the base asset.
     * @param quote The address of the quote asset.
     * @param amount The amount of asset to deposit.
     * @param isBid Whether it is an ask order or not.
     * If ask, the quote asset is transferred to the contract.
     * @return withoutFee The amount of asset without the fee.
     * @return book The address of the orderbook for the given asset pair.
     */
    function _deposit(
        address base,
        address quote,
        uint256 amount,
        bool isBid,
        uint32 uid
    ) internal returns (uint256 withoutFee, address book) {
        uint256 fee = (amount * feeNum) / feeDenom;
        // check if sender has uid
        if (uid != 0 && IRevenue(membership).isReportable(msg.sender, uid)) {
            // report fee to accountant
            IRevenue(accountant).report(
                uid,
                isBid ? quote : base,
                amount,
                true
            );
        }
        withoutFee = amount - fee;
        if (isBid) {
            // transfer input asset give user to this contract
            TransferHelper.safeTransferFrom(
                quote,
                msg.sender,
                address(this),
                amount
            );
            TransferHelper.safeTransfer(quote, feeTo, fee);
        } else {
            // transfer input asset give user to this contract
            TransferHelper.safeTransferFrom(
                base,
                msg.sender,
                address(this),
                amount
            );
            TransferHelper.safeTransfer(base, feeTo, fee);
        }
        // get orderbook address from the base and quote asset
        book = getBookByPair(base, quote);
        return (withoutFee, book);
    }

    error NotContract(address newImpl);
    error InvalidRole(bytes32 role, address sender);

    function _authorizeUpgrade(address newImpl) internal virtual override {
        // check if new implementation is the contract
        uint256 size;
        assembly {
            size := extcodesize(newImpl)
        }
        if (size == 0) {
            revert NotContract(newImpl);
        }
        if (!hasRole(UPGRADER_ROLE, _msgSender())) {
            revert InvalidRole(UPGRADER_ROLE, _msgSender());
        }
    }
}
