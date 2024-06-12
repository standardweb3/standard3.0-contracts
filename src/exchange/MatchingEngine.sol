// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;
import {IOrderbookFactory} from "./interfaces/IOrderbookFactory.sol";
import {IOrderbook, ExchangeOrderbook} from "./interfaces/IOrderbook.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IRevenue {
    function reportMatch(
        address orderbook,
        address give,
        bool isBid,
        address sender,
        address owner,
        uint256 amount
    ) external;

    function isReportable() external view returns (bool isReportable);

    function feeOf(
        address account,
        bool isMaker
    ) external view returns (uint32 feeNum);

    function isSubscribed(address account) external view returns (bool isSubscribed);
}

interface IDecimals {
    function decimals() external view returns (uint8 decimals);
}

// Onchain Matching engine for the orders
contract MatchingEngine is Initializable, ReentrancyGuard, AccessControl {
    // Listing coordinator role
    bytes32 private LISTING_COORDINATOR_ROLE =
        keccak256("LISTING_COORDINATOR_ROLE");
    // Market maker role
    bytes32 private MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");
    // fee recipient for point storage
    address private feeTo;
    // fee denominator representing 0.001%, 1/1000000 = 0.001%
    uint32 public immutable feeDenom = 1000000;
    // Factories
    address public orderbookFactory;
    // WETH
    address public WETH;
    // default buy spread
    uint32 defaultBuy = 200;
    // default sell spread
    uint32 defaultSell = 200;

    struct OrderData {
        /// Amount after removing fee
        uint256 withoutFee;
        /// Orderbook contract address
        address orderbook;
        /// Head price on bid orderbook, the highest bid price
        uint256 bidHead;
        /// Head price on ask orderbook, the lowest ask price
        uint256 askHead;
        /// Market price on pair
        uint256 mp;
        /// Spread(volatility) limit on limit/market | buy/sell for market suspensions(e.g. circuit breaker, tick)
        uint32 spreadLimit;
        /// Make order id
        uint32 makeId;
        /// Whether an order deposit has been cleared
        bool clear;
    }

    struct DefaultSpread {
        /// Buy spread limit
        uint32 buy;
        /// Sell spread limit
        uint32 sell;
    }

    // Spread limit setting
    mapping(address => DefaultSpread) public spreadLimits;

    event OrderDeposit(address sender, address asset, uint256 fee);

    event OrderCanceled(
        address orderbook,
        uint256 id,
        bool isBid,
        address indexed owner,
        uint256 amount
    );

    /**
     * @dev This event is emitted when an order is successfully matched with a counterparty.
     * @param orderbook The address of the order book contract to get base and quote asset contract address.
     * @param id The unique identifier of the canceled order in bid/ask order database.
     * @param isBid A boolean indicating whether the matched order is a bid (true) or ask (false).
     * @param sender The address initiating the match.
     * @param owner The address of the order owner whose order is matched with the sender.
     * @param price The price at which the order is matched.
     * @param amount The matched amount of the asset being traded in the match. if isBid==false, it is base asset, if isBid==true, it is quote asset.
     * @param clear whether or not the order is cleared
     */
    event OrderMatched(
        address orderbook,
        uint256 id,
        bool isBid,
        address sender,
        address owner,
        uint256 price,
        uint256 amount,
        bool clear
    );

    event OrderPlaced(
        address orderbook,
        uint256 id,
        address owner,
        bool isBid,
        uint256 price,
        uint256 withoutFee,
        uint256 placed
    );

    event PairAdded(
        address orderbook,
        address base,
        address quote,
        uint8 bDecimal,
        uint8 qDecimal
    );

    error TooManyMatches(uint256 n);
    error InvalidFeeRate(uint256 feeNum, uint256 feeDenom);
    error NotContract(address newImpl);
    error InvalidRole(bytes32 role, address sender);
    error OrderSizeTooSmall(uint256 amount, uint256 minRequired);
    error NoOrderMade(address base, address quote);
    error InvalidPair(address base, address quote, address pair);
    error NoLastMatchedPrice(address base, address quote);
    error BidPriceTooLow(uint256 limitPrice, uint256 lmp, uint256 minBidPrice);
    error AskPriceTooHigh(uint256 limitPrice, uint256 lmp, uint256 maxAskPrice);
    error PairDoesNotExist(address base, address quote, address pair);
    error AmountIsZero();

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LISTING_COORDINATOR_ROLE, msg.sender);
        _grantRole(MARKET_MAKER_ROLE, msg.sender);
    }

    /**
     * @dev Initialize the matching engine with orderbook factory and listing requirements.
     * It can be called only once.
     * @param orderbookFactory_ address of orderbook factory
     * @param feeTo_ address to receive fee
     * @param WETH_ address of wrapped ether contract
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function initialize(
        address orderbookFactory_,
        address feeTo_,
        address WETH_
    ) external initializer {
        orderbookFactory = orderbookFactory_;
        feeTo = feeTo_;
        WETH = WETH_;
    }

    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        feeTo = feeTo_;
    }

    function setDefaultSpread(
        uint32 buy,
        uint32 sell
    ) external returns (bool success) {
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        defaultBuy = buy;
        defaultSell = sell;
    }

    function setSpread(
        address base,
        address quote,
        uint32 buy,
        uint32 sell
    ) external returns (bool success) {
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        _setSpread(base, quote, buy, sell);
    }

    // user functions

    /**
     * @dev Executes a market buy order, with spread limit of 1% for price actions.
     * buys the base asset using the quote asset at the best available price in the orderbook up to `n` orders,
     * and make an order at the market price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param quoteAmount The amount of quote asset to be used for the market buy order
     * @param isMaker Boolean indicating if a order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the order owner
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketBuy(
        address base,
        address quote,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    )
        public
        nonReentrant
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        OrderData memory orderData;

        // reuse quoteAmount variable as minRequired from _deposit to avoid stack too deep error
        (orderData.withoutFee, orderData.orderbook) = _deposit(
            base,
            quote,
            0,
            quoteAmount,
            true,
            isMaker
        );

        // get spread limits
        orderData.spreadLimit = _getSpread(orderData.orderbook, true);

        orderData.mp = mktPrice(base, quote);

        // reuse quoteAmount for storing amount after taking fees
        quoteAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount due to stack too deep error
        (
            orderData.withoutFee,
            orderData.bidHead,
            orderData.askHead
        ) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            quote,
            recipient,
            true,
            (orderData.mp * (10000 + orderData.spreadLimit)) / 10000,
            n
        );

        // reuse orderData.bidHead argument for storing make price
        orderData.bidHead = _detMarketBuyMakePrice(
            orderData.orderbook,
            orderData.bidHead,
            orderData.askHead,
            orderData.spreadLimit
        );

        // add make order on market price, reuse orderData.ls for storing placed Order id
        orderData.makeId = _detMake(
            base,
            quote,
            orderData.orderbook,
            orderData.withoutFee,
            orderData.bidHead,
            true,
            isMaker,
            recipient
        );

        // check if order id is made
        if (orderData.makeId > 0) {
            //if made, set last market price to orderData.bidHead
            IOrderbook(orderData.orderbook).setLmp(orderData.bidHead);
            emit OrderPlaced(
                orderData.orderbook,
                orderData.makeId,
                recipient,
                true,
                orderData.bidHead,
                quoteAmount,
                orderData.withoutFee
            );
        }

        return (orderData.bidHead, orderData.withoutFee, orderData.makeId);
    }

    function _detMarketBuyMakePrice(
        address orderbook,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 up;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return up;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (10000 + spread)) / 10000;
                return up;
            }
            up = (bidHead * (10000 + spread)) / 10000;
            return up;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return askHead >= up ? up : askHead;
            }
            return askHead;
        } else {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (10000 + spread)) / 10000;
                return askHead >= up ? up : askHead;
            }
            return askHead;
        }
    }

    /**
     * @dev Executes a market sell order, with spread limit of 5% for price actions.
     * sells the base asset for the quote asset at the best available price in the orderbook up to `n` orders,
     * and make an order at the market price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param baseAmount The amount of base asset to be sold in the market sell order
     * @param isMaker Boolean indicating if an order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketSell(
        address base,
        address quote,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    )
        public
        nonReentrant
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(
            base,
            quote,
            0,
            baseAmount,
            false,
            isMaker
        );

        // get spread limits
        orderData.spreadLimit = _getSpread(orderData.orderbook, false);

        orderData.mp = mktPrice(base, quote);

        // reuse baseAmount for storing without fee
        baseAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (
            orderData.withoutFee,
            orderData.bidHead,
            orderData.askHead
        ) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            base,
            recipient,
            false,
            (orderData.mp * (10000 - orderData.spreadLimit)) / 10000,
            n
        );

        // reuse orderData.askHead argument for storing make price
        orderData.askHead = _detMarketSellMakePrice(
            orderData.orderbook,
            orderData.bidHead,
            orderData.askHead,
            orderData.spreadLimit
        );

        orderData.makeId = _detMake(
            base,
            quote,
            orderData.orderbook,
            orderData.withoutFee,
            orderData.askHead,
            false,
            isMaker,
            recipient
        );

        // check if order id is made
        if (orderData.makeId > 0) {
            //if made, set last market price to orderData.askHead
            IOrderbook(orderData.orderbook).setLmp(orderData.askHead);
            emit OrderPlaced(
                orderData.orderbook,
                orderData.makeId,
                recipient,
                false,
                orderData.askHead,
                baseAmount,
                orderData.withoutFee
            );
        }

        return (orderData.askHead, orderData.withoutFee, orderData.makeId);
    }

    function _detMarketSellMakePrice(
        address orderbook,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 down;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return down == 0 ? 1 : down;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                down = down <= bidHead ? bidHead : down;
                return down == 0 ? 1 : down;
            }
            return bidHead;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (10000 - spread)) / 10000;
                return down == 0 ? 1 : down;
            }
            down = (askHead * (10000 - spread)) / 10000;
            return down == 0 ? 1 : down;
        } else {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (10000 - spread)) / 10000;
                down = down <= bidHead ? bidHead : down;
                return down == 0 ? 1 : down;
            }
            return bidHead;
        }
    }

    /**
     * @dev Executes a market buy order, with spread limit of 5% for price actions.
     * buys the base asset using the quote asset at the best available price in the orderbook up to `n` orders,
     * and make an order at the market price with quote asset as native Ethereum(or other network currencies).
     * @param base The address of the base asset for the trading pair
     * @param isMaker Boolean indicating if a order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketBuyETH(
        address base,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id) {
        IWETH(WETH).deposit{value: msg.value}();
        return marketBuy(base, WETH, msg.value, isMaker, n, uid, recipient);
    }

    /**
     * @dev Executes a market sell order,
     * sells the base asset for the quote asset at the best available price in the orderbook up to `n` orders,
     * and make an order at the market price with base asset as native Ethereum(or other network currencies).
     * @param quote The address of the quote asset for the trading pair
     * @param isMaker Boolean indicating if an order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketSellETH(
        address quote,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id) {
        IWETH(WETH).deposit{value: msg.value}();
        return marketSell(WETH, quote, msg.value, isMaker, n, uid, recipient);
    }

    /**
     * @dev Executes a limit buy order, with spread limit of 5% for price actions.
     * places a limit order in the orderbook for buying the base asset using the quote asset at a specified price,
     * and make an order at the limit price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param price The price, base/quote regardless of decimals of the assets in the pair represented with 8 decimals (if 1000, base is 1000x quote)
     * @param quoteAmount The amount of quote asset to be used for the limit buy order
     * @param isMaker Boolean indicating if an order should be made at the limit price
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function limitBuy(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    )
        public
        nonReentrant
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(
            base,
            quote,
            price,
            quoteAmount,
            true,
            isMaker
        );

        // get spread limits
        orderData.spreadLimit = _getSpread(orderData.orderbook, true);

        // reuse quoteAmount for storing amount without fee
        quoteAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (
            orderData.withoutFee,
            orderData.bidHead,
            orderData.askHead
        ) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            quote,
            recipient,
            true,
            price,
            n
        );

        // reuse price variable for storing make price
        price = _detLimitBuyMakePrice(
            orderData.orderbook,
            price,
            orderData.bidHead,
            orderData.askHead,
            orderData.spreadLimit
        );

        orderData.makeId = _detMake(
            base,
            quote,
            orderData.orderbook,
            orderData.withoutFee,
            price,
            true,
            isMaker,
            recipient
        );

        // check if order id is made
        if (orderData.makeId > 0) {
            emit OrderPlaced(
                orderData.orderbook,
                orderData.makeId,
                recipient,
                true,
                price,
                quoteAmount,
                orderData.withoutFee
            );
        }

        return (price, orderData.withoutFee, orderData.makeId);
    }

    function _detLimitBuyMakePrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 up;
        if (askHead == 0 && bidHead == 0) {
            uint256 lmp = IOrderbook(orderbook).lmp();
            if (lmp != 0) {
                up = (lmp * (10000 + spread)) / 10000;
                return lp >= up ? up : lp;
            }
            return lp;
        } else if (askHead == 0 && bidHead != 0) {
            up = (bidHead * (10000 + spread)) / 10000;
            return lp >= up ? up : lp;
        } else if (askHead != 0 && bidHead == 0) {
            up = (askHead * (10000 + spread)) / 10000;
            up = lp >= up ? up : lp;
            return up >= askHead ? askHead : up;
        } else {
            up = (bidHead * (10000 + spread)) / 10000;
            // First, set upper limit on make price for market suspenstion
            up = lp >= up ? up : lp;
            // upper limit on make price must not go above ask price
            return up >= askHead ? askHead : up;
        }
    }

    /**
     * @dev Executes a limit sell order, with spread limit of 5% for price actions.
     * places a limit order in the orderbook for selling the base asset for the quote asset at a specified price,
     * and makes an order at the limit price.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param price The price, base/quote regardless of decimals of the assets in the pair represented with 8 decimals (if 1000, base is 1000x quote)
     * @param baseAmount The amount of base asset to be used for the limit sell order
     * @param isMaker Boolean indicating if an order should be made at the limit price
     * @param n The maximum number of orders to match in the orderbook
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function limitSell(
        address base,
        address quote,
        uint256 price,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    )
        public
        nonReentrant
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(
            base,
            quote,
            price,
            baseAmount,
            false,
            isMaker
        );

        // get spread limit
        orderData.spreadLimit = _getSpread(orderData.orderbook, false);

        // reuse baseAmount for storing amount without fee
        baseAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (
            orderData.withoutFee,
            orderData.bidHead,
            orderData.askHead
        ) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            base,
            recipient,
            false,
            price,
            n
        );

        // reuse price variable for make price
        price = _detLimitSellMakePrice(
            orderData.orderbook,
            price,
            orderData.bidHead,
            orderData.askHead,
            orderData.spreadLimit
        );

        orderData.makeId = _detMake(
            base,
            quote,
            orderData.orderbook,
            orderData.withoutFee,
            price,
            false,
            isMaker,
            recipient
        );

        if (orderData.makeId > 0) {
            emit OrderPlaced(
                orderData.orderbook,
                orderData.makeId,
                recipient,
                false,
                price,
                baseAmount,
                orderData.withoutFee
            );
        }

        return (price, orderData.withoutFee, orderData.makeId);
    }

    function _detLimitSellMakePrice(
        address orderbook,
        uint256 lp,
        uint256 bidHead,
        uint256 askHead,
        uint32 spread
    ) internal view returns (uint256 price) {
        uint256 down;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return lp <= down ? down : lp;
            }
            return lp;
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (10000 - spread)) / 10000;
                return lp <= down ? down : lp;
            }
            down = (bidHead * (10000 - spread)) / 10000;
            return lp <= down ? down : lp;
        } else if (askHead != 0 && bidHead == 0) {
            down = (askHead * (10000 - spread)) / 10000;
            down = lp <= down ? down : lp;
            return down <= bidHead ? bidHead : down;
        } else {
            down = (bidHead * (10000 - spread)) / 10000;
            // First, set lower limit on down price for market suspenstion
            down = lp <= down ? down : lp;
            // lower limit price on sell cannot be lower than bid head price
            return down <= bidHead ? bidHead : down;
        }
    }

    /**
     * @dev Executes a limit buy order, with spread limit of 5% for price actions.
     * places a limit order in the orderbook for buying the base asset using the quote asset at a specified price,
     * and make an order at the limit price with quote asset as native Ethereum(or network currencies).
     * @param base The address of the base asset for the trading pair
     * @param isMaker Boolean indicating if a order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function limitBuyETH(
        address base,
        uint256 price,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id) {
        IWETH(WETH).deposit{value: msg.value}();
        return
            limitBuy(base, WETH, price, msg.value, isMaker, n, uid, recipient);
    }

    /**
     * @dev Executes a limit sell order, with spread limit of 5% for price actions.
     * places a limit order in the orderbook for selling the base asset for the quote asset at a specified price,
     * and makes an order at the limit price with base asset as native Ethereum(or network currencies).
     * @param quote The address of the quote asset for the trading pair
     * @param isMaker Boolean indicating if an order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function limitSellETH(
        address quote,
        uint256 price,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id) {
        IWETH(WETH).deposit{value: msg.value}();
        return
            limitSell(
                WETH,
                quote,
                price,
                msg.value,
                isMaker,
                n,
                uid,
                recipient
            );
    }

    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param initMarketPrice The initial market price for the trading pair
     * @return book The address of the newly created orderbook
     */
    function addPair(
        address base,
        address quote,
        uint256 initMarketPrice
    ) external returns (address book) {
        if (!hasRole(LISTING_COORDINATOR_ROLE, _msgSender())) {
            revert InvalidRole(LISTING_COORDINATOR_ROLE, _msgSender());
        }
        // create orderbook for the pair
        address orderbook = IOrderbookFactory(orderbookFactory).createBook(
            base,
            quote
        );
        IOrderbook(orderbook).setLmp(initMarketPrice);
        uint8 bDecimal = IDecimals(base).decimals();
        uint8 qDecimal = IDecimals(quote).decimals();
        // set limit spread to 2% and market spread to 5% for default pair
        _setSpread(base, quote, defaultBuy, defaultSell);
        emit PairAdded(orderbook, base, quote, bDecimal, qDecimal);
        return orderbook;
    }

    function _addPair(
        address base,
        address quote
    ) internal returns (address book) {
        // create orderbook for the pair
        address orderBook = IOrderbookFactory(orderbookFactory).createBook(
            base,
            quote
        );
        uint8 bDecimal = IDecimals(base).decimals();
        uint8 qDecimal = IDecimals(quote).decimals();
        // set limit spread to 2% and market spread to 5% for default pair
        _setSpread(base, quote, defaultBuy, defaultSell);
        emit PairAdded(orderBook, base, quote, bDecimal, qDecimal);
        return orderBook;
    }

    /**
     * @dev Cancels an order in an orderbook by the given order ID and order type.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param isBid Boolean indicating if the order to cancel is an ask order
     * @param orderId The ID of the order to cancel
     * @return refunded Refunded amount from order
     */
    function cancelOrder(
        address base,
        address quote,
        bool isBid,
        uint32 orderId
    ) public nonReentrant returns (uint256 refunded) {
        address orderbook = IOrderbookFactory(orderbookFactory).getPair(
            base,
            quote
        );

        if (orderbook == address(0)) {
            revert InvalidPair(base, quote, orderbook);
        }

        uint256 remaining = IOrderbook(orderbook).cancelOrder(
            isBid,
            orderId,
            msg.sender
        );

        emit OrderCanceled(orderbook, orderId, isBid, msg.sender, remaining);
        return remaining;
    }

    function cancelOrders(
        address[] memory base,
        address[] memory quote,
        bool[] memory isBid,
        uint32[] memory orderIds
    ) external returns (uint256[] memory refunded) {
        refunded = new uint256[](orderIds.length);
        for (uint32 i = 0; i < orderIds.length; i++) {
            refunded[i] = cancelOrder(base[i], quote[i], isBid[i], orderIds[i]);
        }
        return refunded;
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
        uint256 start,
        uint256 end
    ) external view returns (IOrderbookFactory.Pair[] memory pairs) {
        return IOrderbookFactory(orderbookFactory).getPairs(start, end);
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return pairs list of pairs from start to end
     */
    function getPairsWithIds(
        uint256[] memory ids
    ) external view returns (IOrderbookFactory.Pair[] memory pairs) {
        return IOrderbookFactory(orderbookFactory).getPairsWithIds(ids);
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return names list of pair names from start to end
     */
    function getPairNames(
        uint256 start,
        uint256 end
    ) external view returns (string[] memory names) {
        return IOrderbookFactory(orderbookFactory).getPairNames(start, end);
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return names list of pair names from start to end
     */
    function getPairNamesWithIds(
        uint256[] memory ids
    ) external view returns (string[] memory names) {
        return IOrderbookFactory(orderbookFactory).getPairNamesWithIds(ids);
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return mktPrices list of mktPrices from start to end
     */
    function getMktPrices(
        uint256 start,
        uint256 end
    ) external view returns (uint256[] memory mktPrices) {
        IOrderbookFactory.Pair[] memory pairs = IOrderbookFactory(
            orderbookFactory
        ).getPairs(start, end);
        mktPrices = new uint256[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            try this.mktPrice(pairs[i].base, pairs[i].quote) returns (
                uint256 price
            ) {
                uint256 p = price;
                mktPrices[i] = p;
            } catch {
                uint256 p = 0;
                mktPrices[i] = p;
            }
        }
        return mktPrices;
    }

    /**
     * @dev returns addresses of pairs in OrderbookFactory registry
     * @return mktPrices list of mktPrices from start to end
     */
    function getMktPricesWithIds(
        uint256[] memory ids
    ) external view returns (uint256[] memory mktPrices) {
        IOrderbookFactory.Pair[] memory pairs = IOrderbookFactory(
            orderbookFactory
        ).getPairsWithIds(ids);
        mktPrices = new uint256[](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            try this.mktPrice(pairs[i].base, pairs[i].quote) returns (
                uint256 price
            ) {
                uint256 p = price;
                mktPrices[i] = p;
            } catch {
                uint256 p = 0;
                mktPrices[i] = p;
            }
        }
        return mktPrices;
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
        uint32 n
    ) external view returns (uint256[] memory) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getPrices(isBid, n);
    }

    function getPricesPaginated(
        address base,
        address quote,
        bool isBid,
        uint32 start,
        uint32 end
    ) external view returns (uint256[] memory) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getPricesPaginated(isBid, start, end);
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
        uint32 n
    ) external view returns (ExchangeOrderbook.Order[] memory) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getOrders(isBid, price, n);
    }

    function getOrdersPaginated(
        address base,
        address quote,
        bool isBid,
        uint256 price,
        uint32 start,
        uint32 end
    ) external view returns (ExchangeOrderbook.Order[] memory) {
        address orderbook = getPair(base, quote);
        return
            IOrderbook(orderbook).getOrdersPaginated(isBid, price, start, end);
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
        uint32 orderId
    ) public view returns (ExchangeOrderbook.Order memory) {
        address orderbook = getPair(base, quote);
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
        uint32 n
    ) external view returns (uint32[] memory) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getOrderIds(isBid, price, n);
    }

    /**
     * @dev Returns the address of the orderbook for the given base and quote asset addresses.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @return book The address of the orderbook.
     */
    function getPair(
        address base,
        address quote
    ) public view returns (address book) {
        return IOrderbookFactory(orderbookFactory).getPair(base, quote);
    }

    function heads(
        address base,
        address quote
    ) external view returns (uint256 bidHead, uint256 askHead) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).heads();
    }

    function mktPrice(
        address base,
        address quote
    ) public view returns (uint256) {
        address orderbook = getPair(base, quote);
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
    ) public view returns (uint256 converted) {
        address orderbook = getPair(base, quote);
        if (base == quote) {
            return amount;
        } else if (orderbook == address(0)) {
            return 0;
        } else {
            return IOrderbook(orderbook).assetValue(amount, isBid);
        }
    }

    function _setSpread(
        address base,
        address quote,
        uint32 buy,
        uint32 sell
    ) internal returns (bool success) {
        address book = getPair(base, quote);
        spreadLimits[book] = DefaultSpread(buy, sell);
        return true;
    }

    function _getSpread(
        address book,
        bool isBuy
    ) internal view returns (uint32 spreadLimit) {
        DefaultSpread memory spread;
        spread = spreadLimits[book];
        if (isBuy) {
            return spread.buy;
        } else {
            return spread.sell;
        }
    }

    /**
     * @dev Internal function which makes an order on the orderbook.
     * @param orderbook The address of the orderbook contract for the trading pair
     * @param withoutFee The remaining amount of the asset after the market order has been executed
     * @param price The price, base/quote regardless of decimals of the assets in the pair represented with 8 decimals (if 1000, base is 1000x quote)
     * @param isBid Boolean indicating if the order is a buy (false) or a sell (true)
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     */
    function _makeOrder(
        address orderbook,
        uint256 withoutFee,
        uint256 price,
        bool isBid,
        address recipient
    ) internal returns (uint32 id) {
        // create order
        if (isBid) {
            id = IOrderbook(orderbook).placeBid(recipient, price, withoutFee);
        } else {
            id = IOrderbook(orderbook).placeAsk(recipient, price, withoutFee);
        }
        return id;
    }

    /**
     * @dev Match bid if `isBid` is true, match ask if `isBid` is false.
     */
    function _matchAt(
        address orderbook,
        address give,
        address recipient,
        bool isBid,
        uint256 amount,
        uint256 price,
        uint32 i,
        uint32 n
    ) internal returns (uint256 remaining, uint32 k) {
        if (n > 20) {
            revert TooManyMatches(n);
        }
        remaining = amount;
        while (
            remaining > 0 &&
            !IOrderbook(orderbook).isEmpty(!isBid, price) &&
            i < n
        ) {
            // fpop OrderLinkedList by price, if ask you get bid order, if bid you get ask order. Get quote asset on bid order on buy, base asset on ask order on sell
            (uint32 orderId, uint256 required, bool clear) = IOrderbook(
                orderbook
            ).fpop(!isBid, price, remaining);
            // order exists, and amount is not 0
            if (remaining <= required) {
                // execute order
                TransferHelper.safeTransfer(give, orderbook, remaining);
                address owner = IOrderbook(orderbook).execute(
                    orderId,
                    !isBid,
                    recipient,
                    remaining,
                    clear
                );
                // report points on match
                _report(orderbook, give, isBid, remaining, owner); 
                // emit event order matched
                emit OrderMatched(
                    orderbook,
                    orderId,
                    isBid,
                    recipient,
                    owner,
                    price,
                    remaining,
                    clear
                );
                // end loop as remaining is 0
                return (0, n);
            }
            // order is null
            else if (required == 0) {
                ++i;
                continue;
            }
            // remaining >= depositAmount
            else {
                remaining -= required;
                TransferHelper.safeTransfer(give, orderbook, required);
                address owner = IOrderbook(orderbook).execute(
                    orderId,
                    !isBid,
                    recipient,
                    required,
                    clear
                );
                // report points on match
                _report(orderbook, give, isBid, required, owner); 
                // emit event order matched
                emit OrderMatched(
                    orderbook,
                    orderId,
                    isBid,
                    recipient,
                    owner,
                    price,
                    required,
                    clear
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
     * @param recipient The address to receive asset after matching a trade
     * @param isBid True if the order is an ask (sell) order, false if it is a bid (buy) order.
     * @param limitPrice The maximum price at which the order can be executed.
     * @param n The maximum number of matches to execute.
     * @return remaining The remaining amount of asset that was not traded.
     */
    function _limitOrder(
        address orderbook,
        uint256 amount,
        address give,
        address recipient,
        bool isBid,
        uint256 limitPrice,
        uint32 n
    ) internal returns (uint256 remaining, uint256 bidHead, uint256 askHead) {
        remaining = amount;
        uint256 lmp = IOrderbook(orderbook).lmp();
        bidHead = IOrderbook(orderbook).clearEmptyHead(true);
        askHead = IOrderbook(orderbook).clearEmptyHead(false);
        uint32 i = 0;
        // In LimitBuy
        if (isBid) {
            if (lmp != 0) {
                if (askHead != 0 && limitPrice < askHead) {
                    return (remaining, bidHead, askHead);
                } else if(askHead == 0) {
                    return (remaining, bidHead, askHead);
                }
            }
            // check if there is any matching ask order until matching ask order price is lower than the limit bid Price
            while (
                remaining > 0 && askHead != 0 && askHead <= limitPrice && i < n
            ) {
                lmp = askHead;
                (remaining, i) = _matchAt(
                    orderbook,
                    give,
                    recipient,
                    isBid,
                    remaining,
                    askHead,
                    i,
                    n
                );
                // i == 0 when orders are all empty and only head price is left
                askHead = i == 0
                    ? 0
                    : IOrderbook(orderbook).clearEmptyHead(false);
            }
            // update heads
            bidHead = IOrderbook(orderbook).clearEmptyHead(true);
        }
        // In LimitSell
        else {
            // check limit ask price is within 20% spread of last matched price
            if (lmp != 0) {
                if (bidHead != 0 && limitPrice > bidHead) {
                    return (remaining, bidHead, askHead);
                } else if(bidHead == 0) {
                    return (remaining, bidHead, askHead);
                }
            }
            while (
                remaining > 0 && bidHead != 0 && bidHead >= limitPrice && i < n
            ) {
                lmp = bidHead;
                (remaining, i) = _matchAt(
                    orderbook,
                    give,
                    recipient,
                    isBid,
                    remaining,
                    bidHead,
                    i,
                    n
                );
                // i == 0 when orders are all empty and only head price is left
                bidHead = i == 0
                    ? 0
                    : IOrderbook(orderbook).clearEmptyHead(true);
            }
            // update heads
            askHead = IOrderbook(orderbook).clearEmptyHead(false);
        }
        // if orderbooks are empty, set last market price for preserving asset price
        if (bidHead == 0 && askHead == 0 && lmp != 0) {
            IOrderbook(orderbook).setLmp(lmp);
        }

        return (remaining, bidHead, askHead); // return bidHead, and askHead
    }

    /**
     * @dev Determines if an order can be made at the market price,
     * and if so, makes the an order on the orderbook.
     * If an order cannot be made, transfers the remaining asset to either the orderbook or the user.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param orderbook The address of the orderbook contract for the trading pair
     * @param remaining The remaining amount of the asset after the market order has been taken
     * @param price The price used to determine if an order can be made
     * @param isBid Boolean indicating if the order was a buy (true) or a sell (false)
     * @param isMaker Boolean indicating if an order is for storing in orderbook
     * @param recipient The address to receive asset after matching a trade and making an order
     * @return id placed order id
     */
    function _detMake(
        address base,
        address quote,
        address orderbook,
        uint256 remaining,
        uint256 price,
        bool isBid,
        bool isMaker,
        address recipient
    ) internal returns (uint32 id) {
        if (remaining > 0) {
            address stopTo = isMaker ? orderbook : recipient;
            TransferHelper.safeTransfer(
                isBid ? quote : base,
                stopTo,
                remaining
            );
            if (isMaker) {
                id = _makeOrder(orderbook, remaining, price, isBid, recipient);
                return id;
            }
        }
    }

    function _report(
        address orderbook,
        address give,
        bool isBid,
        uint256 matched,
        address owner
    ) internal {
        if (
            _isContract(feeTo) &&
            IRevenue(feeTo).isReportable() &&
            matched > 0 
        ) {
            // report matched amount to accountant with give token on matching order
            IRevenue(feeTo).reportMatch(
                orderbook,
                give,
                isBid,
                msg.sender,
                owner,
                matched
            );
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
     * @return pair The address of the orderbook for the given asset pair.
     */
    function _deposit(
        address base,
        address quote,
        uint256 price,
        uint256 amount,
        bool isBid,
        bool isMaker
    ) internal returns (uint256 withoutFee, address pair) {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }
        // get orderbook address from the base and quote asset
        pair = getPair(base, quote);
        if (pair == address(0)) {
            revert InvalidPair(base, quote, pair);
        }

        // check if amount is valid in case of both market and limit
        uint256 converted = _convert(pair, price, amount, !isBid);
        uint256 minRequired = _convert(pair, price, 1, !isBid);

        if (converted <= minRequired) {
            revert OrderSizeTooSmall(converted, minRequired);
        }
        // check if sender has uid
        uint256 fee = _fee(amount, msg.sender, isMaker);
        withoutFee = amount - fee;
        if (isBid) {
            // transfer input asset give user to this contract
            if (quote != WETH) {
                TransferHelper.safeTransferFrom(
                    quote,
                    msg.sender,
                    address(this),
                    amount
                );
            }
            TransferHelper.safeTransfer(quote, feeTo, fee);
        } else {
            // transfer input asset give user to this contract
            if (base != WETH) {
                TransferHelper.safeTransferFrom(
                    base,
                    msg.sender,
                    address(this),
                    amount
                );
            }
            TransferHelper.safeTransfer(base, feeTo, fee);
        }
        emit OrderDeposit(msg.sender, isBid ? quote : base, fee);

        return (withoutFee, pair);
    }

    function _fee(
        uint256 amount,
        address account,
        bool isMaker
    ) internal view returns (uint256 fee) {
        if (_isContract(feeTo) && IRevenue(feeTo).isSubscribed(account)) {
            uint32 feeNum = IRevenue(feeTo).feeOf(account, isMaker);
            return (amount * feeNum) / feeDenom;
        }
        return amount / 100;
    }

    function _isContract(address addr) internal view returns (bool isContract) {
        uint size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @dev return converted amount from base to quote or vice versa
     * @param orderbook address of orderbook
     * @param price price of base/quote regardless of decimals of the assets in the pair represented with 8 decimals (if 1000, base is 1000x quote) proposed by a trader
     * @param amount amount of base or quote asset
     * @param isBid if true, amount is quote asset, otherwise base asset
     * @return converted converted amount from base to quote or vice versa.
     * if true, amount is quote asset, otherwise base asset
     * if orderbook does not exist, return 0
     */
    function _convert(
        address orderbook,
        uint256 price,
        uint256 amount,
        bool isBid
    ) internal view returns (uint256 converted) {
        if (orderbook == address(0)) {
            return 0;
        } else {
            return
                price == 0
                    ? IOrderbook(orderbook).assetValue(amount, isBid)
                    : IOrderbook(orderbook).convert(price, amount, isBid);
        }
    }
}
