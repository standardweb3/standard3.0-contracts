// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import {IOrderbookFactory} from "./interfaces/IOrderbookFactory.sol";
import {IOrderbook, ExchangeOrderbook} from "./interfaces/IOrderbook.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IProtocol {
    function feeOf(address base, address quote, address account, bool isMaker) external view returns (uint32 feeNum);

    function isSubscribed(address account) external view returns (bool isSubscribed);

    function terminalName(address terminal) external view returns (string memory terminalName);
}

// Onchain Matching engine for the orders
contract MatchingEngine is ReentrancyGuard, AccessControl {
    // Market maker role
    bytes32 private constant MARKET_MAKER_ROLE = keccak256("MARKET_MAKER_ROLE");
    // fee recipient for point storage
    address private feeTo;
    // incentive address
    address private incentive;
    // base fee in numerator for DENOM
    uint32 private baseFee = 100000;
    // Denominator for fraction calculation overall
    uint32 public constant DENOM = 100000000;
    // Factories
    address public orderbookFactory;
    // WETH
    address public WETH;
    // default buy spread
    uint32 defaultBuy;
    // default sell spread
    uint32 defaultSell;
    // bool on initialization
    bool init;
    // max matches
    uint32 maxMatches;

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
        uint256 lmp;
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

    // Listing Info setting
    mapping(address => uint256) public listingDates;

    event OrderDeposit(address sender, address asset, uint256 fee);

    event OrderCanceled(address pair, uint256 id, bool isBid, address indexed owner, uint256 amount);

    event NewMarketPrice(address pair, uint256 price, bool isBid);
    event ListingCostSet(address payment, uint256 amount);

    /**
     * @dev This event is emitted when an order is successfully matched with a counterparty.
     * @param pair The address of the order book contract to get base and quote asset contract address.
     * @param id The unique identifier of the canceled order in bid/ask order database.
     * @param isBid A boolean indicating whether the matched order is a bid (true) or ask (false).
     * @param sender The address initiating the match.
     * @param owner The address of the order owner whose order is matched with the sender.
     * @param price The price at which the order is matched.
     * @param amount The matched amount of the asset being traded in the match. if isBid==false, it is base asset, if isBid==true, it is quote asset.
     * @param clear whether or not the order is cleared
     */
    event OrderMatched(
        address pair,
        uint256 id,
        bool isBid,
        address sender,
        address owner,
        uint256 price,
        uint256 amount,
        bool clear
    );

    event OrderPlaced(
        address pair, uint256 id, address owner, bool isBid, uint256 price, uint256 withoutFee, uint256 placed
    );

    event PairAdded(
        address pair,
        TransferHelper.TokenInfo base,
        TransferHelper.TokenInfo quote,
        uint256 listingPrice,
        uint256 listingDate,
        string supportedTerminals
    );

    event PairUpdated(address pair, address base, address quote, uint256 listingPrice, uint256 listingDate);

    event PairCreate2(address deployer, bytes bytecode);

    error TooManyMatches(uint256 n);
    error InvalidRole(bytes32 role, address sender);
    error InvalidTerminal(address terminal);
    error OrderSizeTooSmall(uint256 amount, uint256 minRequired);
    error NoOrderMade(address base, address quote);
    error InvalidPair(address base, address quote, address pair);
    error PairNotListedYet(address base, address quote, uint256 listingDate, uint256 timeNow);
    error NoLastMatchedPrice(address base, address quote);
    error BidPriceTooLow(uint256 limitPrice, uint256 lmp, uint256 minBidPrice);
    error AskPriceTooHigh(uint256 limitPrice, uint256 lmp, uint256 maxAskPrice);
    error PairDoesNotExist(address base, address quote, address pair);
    error AmountIsZero();
    error FactoryNotInitialized(address factory);
    error AlreadyInitialized(bool init);

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
    function initialize(address orderbookFactory_, address feeTo_, address WETH_) external {
        if (init) {
            revert AlreadyInitialized(init);
        }
        orderbookFactory = orderbookFactory_;
        feeTo = feeTo_;
        WETH = WETH_;
        defaultBuy = 100000;
        defaultSell = 100000;
        // get impl address of orderbook contract to predict address
        address impl = IOrderbookFactory(orderbookFactory_).impl();
        // Orderbook factory must be initialized first to locate pairs
        if (impl == address(0)) {
            revert FactoryNotInitialized(orderbookFactory_);
        }
        bytes memory bytecode = IOrderbookFactory(orderbookFactory_).getByteCode();
        init = true;
        maxMatches = 20;
        emit PairCreate2(orderbookFactory, bytecode);
    }

    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        feeTo = feeTo_;
        return true;
    }

    function setIncentive(address incentive_) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        incentive = incentive_;
        return true;
    }

    function setBaseFee(uint32 baseFee_) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        baseFee = baseFee_;
        return true;
    }

    function setMaxMatches(uint32 n) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        maxMatches = n;
        return true;
    }

    /**
     * @dev Set the listing cost for a token. Each pair costs minimum 2GB of data storage in a month, costing 0.1 ETH.
     * @param terminal terminal name
     * @param payment address of payment token
     * @param amount amount of token
     *
     * Requirements:
     * - `msg.sender` must have the default admin role.
     */
    function setListingCost(string memory terminal, address payment, uint256 amount) external returns (uint256) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        IOrderbookFactory(orderbookFactory).setListingCost(terminal, payment, amount);
        emit ListingCostSet(payment, amount);
        return amount;
    }

    function setDefaultSpread(uint32 buy, uint32 sell) external returns (bool success) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert InvalidRole(DEFAULT_ADMIN_ROLE, _msgSender());
        }
        defaultBuy = buy;
        defaultSell = sell;
        return true;
    }

    // market maker functions

    function setSpread(address base, address quote, uint32 buy, uint32 sell) external returns (bool success) {
        // get pair
        address pair = IOrderbookFactory(orderbookFactory).getPair(base, quote);
        if (pair == address(0)) {
            revert PairDoesNotExist(base, quote, pair);
        }

        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            if (!hasRole(bytes32(abi.encodePacked(pair)), _msgSender())) {
                revert InvalidRole(bytes32(abi.encodePacked(pair)), _msgSender());
            }
        }

        _setSpread(base, quote, buy, sell);
        return true;
    }

    /**
     * @dev Adjust the orderbook to market price
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param isBuy Boolean indicating if the order is buy or sell
     * @param price The price to adjust
     * @param assetAmount The amount of adjusting asset to set price in buy or sell position
     * @param beforeAdjust The price before adjustment
     * @param afterAdjust The price after adjustment
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function adjustPrice(
        address base,
        address quote,
        bool isBuy,
        uint256 price,
        uint256 assetAmount,
        uint32 beforeAdjust,
        uint32 afterAdjust,
        bool isMaker,
        uint32 n
    ) external returns (uint256 makePrice, uint256 placed, uint32 id) {
        // get pair
        address pair = IOrderbookFactory(orderbookFactory).getPair(base, quote);
        if (pair == address(0)) {
            revert PairDoesNotExist(base, quote, pair);
        }

        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            if (!hasRole(bytes32(abi.encodePacked(pair)), _msgSender())) {
                revert InvalidRole(bytes32(abi.encodePacked(pair)), _msgSender());
            }
        }

        // get spreads in the pair
        // check if the sell spread to decrease price is greater than 100%
        if (beforeAdjust > 100000000 && !isBuy) {
            revert("Sell Spread too high, making underflow");
        }

        uint32 buySpread = isBuy ? beforeAdjust : getSpread(pair, true);
        uint32 sellSpread = !isBuy ? beforeAdjust : getSpread(pair, false);
        // change spread in the pair to adjust price
        _setSpread(base, quote, buySpread, sellSpread);

        // add limit buy or sell order to adjust price
        if (isBuy) {
            (makePrice, placed, id) = limitBuy(base, quote, price, assetAmount, true, n, msg.sender);
        } else {
            (makePrice, placed, id) = limitSell(base, quote, price, assetAmount, true, n, msg.sender);
        }

        // set spreads in the pair to original
        buySpread = isBuy ? afterAdjust : getSpread(pair, true);
        sellSpread = !isBuy ? afterAdjust : getSpread(pair, false);
        _setSpread(base, quote, buySpread, sellSpread);

        // if isMaker, cancel the order and return the fund to MM
        if (!isMaker) {
            cancelOrder(base, quote, isBuy, id);
        }

        return (makePrice, placed, id);
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
     * @param slippageLimit Slippage limit in basis points
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
        address recipient,
        uint32 slippageLimit
    ) public nonReentrant returns (uint256 makePrice, uint256 placed, uint32 id) {
        OrderData memory orderData;

        // reuse quoteAmount variable as minRequired from _deposit to avoid stack too deep error
        (orderData.withoutFee, orderData.orderbook) = _deposit(base, quote, 0, quoteAmount, true, isMaker);

        // get spread limits
        orderData.spreadLimit =
            slippageLimit <= getSpread(orderData.orderbook, true) ? slippageLimit : getSpread(orderData.orderbook, true);

        orderData.lmp = mktPrice(base, quote);

        // reuse quoteAmount for storing amount after taking fees
        quoteAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount due to stack too deep error
        (orderData.withoutFee, orderData.bidHead, orderData.askHead) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            quote,
            recipient,
            true,
            (orderData.lmp * (DENOM + orderData.spreadLimit)) / DENOM,
            n
        );

        // reuse orderData.bidHead argument for storing make price
        orderData.bidHead =
            _detMarketBuyMakePrice(orderData.orderbook, orderData.bidHead, orderData.askHead, orderData.spreadLimit);

        // add make order on market price, reuse orderData.ls for storing placed Order id
        orderData.makeId = _detMake(
            base, quote, orderData.orderbook, orderData.withoutFee, orderData.bidHead, true, isMaker, recipient
        );

        // check if order id is made
        if (orderData.makeId > 0) {
            //if made, set last market price to orderData.bidHead only if orderData.bidHead is greater than lmp
            if (orderData.bidHead > orderData.lmp) {
                IOrderbook(orderData.orderbook).setLmp(orderData.bidHead);
                emit NewMarketPrice(orderData.orderbook, orderData.bidHead, true);
            }
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

    function _detMarketBuyMakePrice(address orderbook, uint256 bidHead, uint256 askHead, uint32 spread)
        internal
        view
        returns (uint256 price)
    {
        uint256 up;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                return up;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (DENOM + spread)) / DENOM;
                return up;
            }
            up = (bidHead * (DENOM + spread)) / DENOM;
            return up;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                return askHead >= up ? up : askHead;
            }
            return askHead;
        } else {
            if (lmp != 0) {
                uint256 temp = (bidHead >= lmp ? bidHead : lmp);
                up = (temp * (DENOM + spread)) / DENOM;
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
     * @param recipient recipient of order for trading
     * @param slippageLimit slippage limit from market order in basis point
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
        address recipient,
        uint32 slippageLimit
    ) public nonReentrant returns (uint256 makePrice, uint256 placed, uint32 id) {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(base, quote, 0, baseAmount, false, isMaker);

        // get spread limits
        orderData.spreadLimit = slippageLimit <= getSpread(orderData.orderbook, false)
            ? slippageLimit
            : getSpread(orderData.orderbook, false);

        orderData.lmp = mktPrice(base, quote);

        // reuse baseAmount for storing without fee
        baseAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (orderData.withoutFee, orderData.bidHead, orderData.askHead) = _limitOrder(
            orderData.orderbook,
            orderData.withoutFee,
            base,
            recipient,
            false,
            (orderData.lmp * (DENOM - orderData.spreadLimit)) / DENOM,
            n
        );

        // reuse orderData.askHead argument for storing make price
        orderData.askHead =
            _detMarketSellMakePrice(orderData.orderbook, orderData.bidHead, orderData.askHead, orderData.spreadLimit);

        orderData.makeId = _detMake(
            base, quote, orderData.orderbook, orderData.withoutFee, orderData.askHead, false, isMaker, recipient
        );

        // check if order id is made
        if (orderData.makeId > 0) {
            //if made, set last market price to orderData.askHead only if askHead is smaller than lmp
            if (orderData.askHead < orderData.lmp) {
                IOrderbook(orderData.orderbook).setLmp(orderData.askHead);
                emit NewMarketPrice(orderData.orderbook, orderData.askHead, false);
            }
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

    function _detMarketSellMakePrice(address orderbook, uint256 bidHead, uint256 askHead, uint32 spread)
        internal
        view
        returns (uint256 price)
    {
        uint256 down;
        uint256 lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            // lmp must exist unless there has been no order in orderbook
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                return down == 0 ? 1 : down;
            }
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                down = down <= bidHead ? bidHead : down;
                return down == 0 ? 1 : down;
            }
            return bidHead;
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (DENOM - spread)) / DENOM;
                return down == 0 ? 1 : down;
            }
            down = (askHead * (DENOM - spread)) / DENOM;
            return down == 0 ? 1 : down;
        } else {
            if (lmp != 0) {
                uint256 temp = lmp <= askHead ? lmp : askHead;
                down = (temp * (DENOM - spread)) / DENOM;
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
     * @param slippageLimit Slippage limit in basis points
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketBuyETH(address base, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        IWETH(WETH).deposit{value: msg.value}();
        return marketBuy(base, WETH, msg.value, isMaker, n, recipient, slippageLimit);
    }

    /**
     * @dev Executes a market sell order,
     * sells the base asset for the quote asset at the best available price in the orderbook up to `n` orders,
     * and make an order at the market price with base asset as native Ethereum(or other network currencies).
     * @param quote The address of the quote asset for the trading pair
     * @param isMaker Boolean indicating if an order should be made at the market price in orderbook
     * @param n The maximum number of orders to match in the orderbook
     * @param recipient The address of the recipient to receive traded asset and claim ownership of made order
     * @param slippageLimit Slippage limit in basis points
     * @return makePrice price where the order is placed
     * @return placed placed amount
     * @return id placed order id
     */
    function marketSellETH(address quote, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        IWETH(WETH).deposit{value: msg.value}();
        return marketSell(WETH, quote, msg.value, isMaker, n, recipient, slippageLimit);
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
        address recipient
    ) public nonReentrant returns (uint256 makePrice, uint256 placed, uint32 id) {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(base, quote, price, quoteAmount, true, isMaker);

        // get spread limits
        orderData.spreadLimit = getSpread(orderData.orderbook, true);

        // reuse quoteAmount for storing amount without fee
        quoteAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (orderData.withoutFee, orderData.bidHead, orderData.askHead) =
            _limitOrder(orderData.orderbook, orderData.withoutFee, quote, recipient, true, price, n);

        // reuse price variable for storing make price, determine
        (price, orderData.lmp) = _detLimitBuyMakePrice(
            orderData.orderbook, price, orderData.bidHead, orderData.askHead, orderData.spreadLimit
        );

        orderData.makeId =
            _detMake(base, quote, orderData.orderbook, orderData.withoutFee, price, true, isMaker, recipient);

        // check if order id is made
        if (orderData.makeId > 0) {
            // if made, set last market price to price only if price is higher than lmp
            if (price > orderData.lmp) {
                IOrderbook(orderData.orderbook).setLmp(price);

                emit NewMarketPrice(orderData.orderbook, price, true);
            }
            emit OrderPlaced(
                orderData.orderbook, orderData.makeId, recipient, true, price, quoteAmount, orderData.withoutFee
            );
        }

        return (price, orderData.withoutFee, orderData.makeId);
    }

    function _detLimitBuyMakePrice(address orderbook, uint256 lp, uint256 bidHead, uint256 askHead, uint32 spread)
        internal
        view
        returns (uint256 price, uint256 lmp)
    {
        uint256 up;
        lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                return (lp >= up ? up : lp, lmp);
            }
            return (lp, lmp);
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                return (lp >= up ? up : lp, lmp);
            }
            up = (bidHead * (DENOM + spread)) / DENOM;
            return (lp >= up ? up : lp, lmp);
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                up = lp >= up ? up : lp;
                return (up >= askHead ? askHead : up, lmp);
            }
            up = (askHead * (DENOM + spread)) / DENOM;
            up = lp >= up ? up : lp;
            return (up >= askHead ? askHead : up, lmp);
        } else {
            if (lmp != 0) {
                up = (lmp * (DENOM + spread)) / DENOM;
                up = lp >= up ? up : lp;
                return (up >= askHead ? askHead : up, lmp);
            }
            // upper limit on make price must not go above ask price
            return (lp >= askHead ? askHead : lp, lmp);
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
        address recipient
    ) public nonReentrant returns (uint256 makePrice, uint256 placed, uint32 id) {
        OrderData memory orderData;
        (orderData.withoutFee, orderData.orderbook) = _deposit(base, quote, price, baseAmount, false, isMaker);

        // get spread limit
        orderData.spreadLimit = getSpread(orderData.orderbook, false);

        // reuse baseAmount for storing amount without fee
        baseAmount = orderData.withoutFee;

        // reuse withoutFee variable for storing remaining amount after matching due to stack too deep error
        (orderData.withoutFee, orderData.bidHead, orderData.askHead) =
            _limitOrder(orderData.orderbook, orderData.withoutFee, base, recipient, false, price, n);

        // reuse price variable for make price
        (price, orderData.lmp) = _detLimitSellMakePrice(
            orderData.orderbook, price, orderData.bidHead, orderData.askHead, orderData.spreadLimit
        );

        orderData.makeId =
            _detMake(base, quote, orderData.orderbook, orderData.withoutFee, price, false, isMaker, recipient);

        if (orderData.makeId > 0) {
            // if made, set last market price to price only if price is lower than lmp
            if (price < orderData.lmp) {
                IOrderbook(orderData.orderbook).setLmp(price);

                emit NewMarketPrice(orderData.orderbook, price, false);
            }
            emit OrderPlaced(
                orderData.orderbook, orderData.makeId, recipient, false, price, baseAmount, orderData.withoutFee
            );
        }

        return (price, orderData.withoutFee, orderData.makeId);
    }

    function _detLimitSellMakePrice(address orderbook, uint256 lp, uint256 bidHead, uint256 askHead, uint32 spread)
        internal
        view
        returns (uint256 price, uint256 lmp)
    {
        uint256 down;
        lmp = IOrderbook(orderbook).lmp();
        if (askHead == 0 && bidHead == 0) {
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                return (lp <= down ? down : lp, lmp);
            }
            return (lp, lmp);
        } else if (askHead == 0 && bidHead != 0) {
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                down = lp <= down ? down : lp;
                return (down <= bidHead ? bidHead : down, lmp);
            }
            down = (bidHead * (DENOM - spread)) / DENOM;
            down = lp <= down ? down : lp;
            return (down <= bidHead ? bidHead : down, lmp);
        } else if (askHead != 0 && bidHead == 0) {
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                return (lp <= down ? down : lp, lmp);
            }
            down = (askHead * (DENOM - spread)) / DENOM;
            return (lp <= down ? down : lp, lmp);
        } else {
            if (lmp != 0) {
                down = (lmp * (DENOM - spread)) / DENOM;
                return (lp <= down ? down : lp, lmp);
            }
            // lower limit price on sell cannot be lower than bid head price
            return (down <= bidHead ? bidHead : lp, lmp);
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
    function limitBuyETH(address base, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        IWETH(WETH).deposit{value: msg.value}();
        return limitBuy(base, WETH, price, msg.value, isMaker, n, recipient);
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
    function limitSellETH(address quote, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id)
    {
        IWETH(WETH).deposit{value: msg.value}();
        return limitSell(WETH, quote, price, msg.value, isMaker, n, recipient);
    }

    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param listingPrice The initial market price for the trading pair
     * @param listingDate The listing Date for the trading pair
     * @return book The address of the newly created orderbook
     */
    function addPairETH(address base, address quote, uint256 listingPrice, uint256 listingDate)
        external
        payable
        returns (address book)
    {
        IWETH(WETH).deposit{value: msg.value}();
        return addPair(base, quote, listingPrice, listingDate, WETH);
    }

    /**
     * @dev Creates an orderbook for a new trading pair and returns its address
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param listingPrice The initial market price for the trading pair
     * @param listingDate The listing Date for the trading pair 
     * @return pair The address of the newly created orderbook
     */
    function addPair(address base, address quote, uint256 listingPrice, uint256 listingDate, address payment)
        public
        returns (address pair)
    {
        string memory terminalName = _listingDeposit(payment, msg.sender);
        
        // create orderbook for the pair
        address orderbook = IOrderbookFactory(orderbookFactory).createBook(base, quote);
        IOrderbook(orderbook).setLmp(listingPrice);
        // set buy/sell spread to default suspension rate in basis point(bps)
        _setSpread(base, quote, defaultBuy, defaultSell);
        _setListingDate(orderbook, listingDate);

        TransferHelper.TokenInfo memory baseInfo = TransferHelper.getTokenInfo(base);
        TransferHelper.TokenInfo memory quoteInfo = TransferHelper.getTokenInfo(quote);
        emit PairAdded(orderbook, baseInfo, quoteInfo, listingPrice, listingDate, terminalName);
        emit NewMarketPrice(orderbook, listingPrice, true);
        return orderbook;
    }

    /**
     * @dev Update the market price of a trading pair.`
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param listingPrice The initial market price for the trading pair
     * @param listingDate The listing Date for the trading pair
     */
    function updatePair(address base, address quote, uint256 listingPrice, uint256 listingDate)
        external
        returns (address pair)
    {
        // check if the list request is done by
        if (!hasRole(MARKET_MAKER_ROLE, _msgSender())) {
            revert InvalidRole(MARKET_MAKER_ROLE, _msgSender());
        }
        // create orderbook for the pair
        pair = getPair(base, quote);
        IOrderbook(pair).setLmp(listingPrice);
        emit PairUpdated(pair, base, quote, listingPrice, listingDate);
        emit NewMarketPrice(pair, listingPrice, true);
        return pair;
    }

    /**
     * @dev Cancels an order in an orderbook by the given order ID and order type.
     * @param base The address of the base asset for the trading pair
     * @param quote The address of the quote asset for the trading pair
     * @param isBid Boolean indicating if the order to cancel is an ask order
     * @param orderId The ID of the order to cancel
     * @return refunded Refunded amount from order
     */
    function cancelOrder(address base, address quote, bool isBid, uint32 orderId)
        public
        nonReentrant
        returns (uint256)
    {
        address orderbook = IOrderbookFactory(orderbookFactory).getPair(base, quote);

        if (orderbook == address(0)) {
            revert InvalidPair(base, quote, orderbook);
        }

        try IOrderbook(orderbook).cancelOrder(isBid, orderId, msg.sender) returns (uint256 refunded) {
            emit OrderCanceled(orderbook, orderId, isBid, msg.sender, refunded);
            return refunded;
        } catch {
            return 0;
        }
    }

    function rematchOrder(
        address base,
        address quote,
        bool isBid,
        uint32 orderId,
        uint256 price,
        uint256 amount,
        uint32 n
    ) external returns (uint256 makePrice, uint256 placed, uint32 id) {
        cancelOrder(base, quote, isBid, orderId);
        // adjust amount from input
        _deposit(base, quote, price, amount, isBid, true);
        // make new limit buy or sell order
        if (isBid) {
            return limitBuy(base, quote, price, amount, true, n, msg.sender);
        } else {
            return limitSell(base, quote, price, amount, true, n, msg.sender);
        }
    }

    function cancelOrders(address[] memory base, address[] memory quote, bool[] memory isBid, uint32[] memory orderIds)
        external
        returns (uint256[] memory refunded)
    {
        refunded = new uint256[](orderIds.length);
        for (uint32 i = 0; i < orderIds.length; i++) {
            refunded[i] = cancelOrder(base[i], quote[i], isBid[i], orderIds[i]);
        }
        return refunded;
    }

    /**
     * @dev Returns prices in the ask/bid orderbook for the given trading pair.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve prices from is an ask orderbook.
     * @param n The number of prices to retrieve.
     */
    function getPrices(address base, address quote, bool isBid, uint32 n) external view returns (uint256[] memory) {
        address orderbook = getPair(base, quote);
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
    function getOrders(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (ExchangeOrderbook.Order[] memory)
    {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getOrders(isBid, price, n);
    }

    /**
     * @dev Returns an order in the ask/bid orderbook for the given trading pair with order id.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @param isBid Boolean indicating if the orderbook to retrieve orders from is an ask orderbook.
     * @param orderId The order id to retrieve.
     */
    function getOrder(address base, address quote, bool isBid, uint32 orderId)
        public
        view
        returns (ExchangeOrderbook.Order memory)
    {
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
    function getOrderIds(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (uint32[] memory)
    {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).getOrderIds(isBid, price, n);
    }

    /**
     * @dev Returns the address of the orderbook for the given base and quote asset addresses.
     * @param base The address of the base asset for the trading pair.
     * @param quote The address of the quote asset for the trading pair.
     * @return book The address of the orderbook.
     */
    function getPair(address base, address quote) public view returns (address book) {
        return IOrderbookFactory(orderbookFactory).getPair(base, quote);
    }

    function heads(address base, address quote) external view returns (uint256 bidHead, uint256 askHead) {
        address orderbook = getPair(base, quote);
        return IOrderbook(orderbook).heads();
    }

    function mktPrice(address base, address quote) public view returns (uint256) {
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
    function convert(address base, address quote, uint256 amount, bool isBid) public view returns (uint256 converted) {
        address orderbook = getPair(base, quote);
        if (base == quote) {
            return amount;
        } else if (orderbook == address(0)) {
            return 0;
        } else {
            return IOrderbook(orderbook).assetValue(amount, isBid);
        }
    }

    function _setListingDate(address book, uint256 listingDate) internal returns (bool success) {
        listingDates[book] = listingDate;
        return true;
    }

    function _setSpread(address base, address quote, uint32 buy, uint32 sell) internal returns (bool success) {
        address book = getPair(base, quote);
        spreadLimits[book] = DefaultSpread(buy, sell);
        return true;
    }

    function getSpread(address book, bool isBuy) public view returns (uint32 spreadLimit) {
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
    function _makeOrder(address orderbook, uint256 withoutFee, uint256 price, bool isBid, address recipient)
        internal
        returns (uint32 id)
    {
        bool foundDmt;
        // create order
        if (isBid) {
            (id, foundDmt) = IOrderbook(orderbook).placeBid(recipient, price, withoutFee);
        } else {
            (id, foundDmt) = IOrderbook(orderbook).placeAsk(recipient, price, withoutFee);
        }
        if (foundDmt) {
            // emit canceling dormant order
            ExchangeOrderbook.Order memory order = IOrderbook(orderbook).removeDmt(isBid);
            emit OrderCanceled(orderbook, id, isBid, order.owner, order.depositAmount);
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
        if (n > maxMatches) {
            revert TooManyMatches(n);
        }
        remaining = amount;
        while (remaining > 0 && !IOrderbook(orderbook).isEmpty(!isBid, price) && i < n) {
            // fpop OrderLinkedList by price, if ask you get bid order, if bid you get ask order. Get quote asset on bid order on buy, base asset on ask order on sell
            (uint32 orderId, uint256 required, bool clear) = IOrderbook(orderbook).fpop(!isBid, price, remaining);
            // order exists, and amount is not 0
            if (remaining <= required) {
                // execute order
                TransferHelper.safeTransfer(give, orderbook, remaining);
                address owner = IOrderbook(orderbook).execute(orderId, !isBid, recipient, remaining, clear);
                // emit event order matched
                emit OrderMatched(orderbook, orderId, isBid, recipient, owner, price, remaining, clear);
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
                address owner = IOrderbook(orderbook).execute(orderId, !isBid, recipient, required, clear);
                // emit event order matched
                emit OrderMatched(orderbook, orderId, isBid, recipient, owner, price, required, clear);
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
                } else if (askHead == 0) {
                    return (remaining, bidHead, askHead);
                }
            }
            // check if there is any matching ask order until matching ask order price is lower than the limit bid Price
            while (remaining > 0 && askHead != 0 && askHead <= limitPrice && i < n) {
                lmp = askHead;
                (remaining, i) = _matchAt(orderbook, give, recipient, isBid, remaining, askHead, i, n);
                // i == 0 when orders are all empty and only head price is left
                askHead = i == 0 ? 0 : IOrderbook(orderbook).clearEmptyHead(false);
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
                } else if (bidHead == 0) {
                    return (remaining, bidHead, askHead);
                }
            }
            while (remaining > 0 && bidHead != 0 && bidHead >= limitPrice && i < n) {
                lmp = bidHead;
                (remaining, i) = _matchAt(orderbook, give, recipient, isBid, remaining, bidHead, i, n);
                // i == 0 when orders are all empty and only head price is left
                bidHead = i == 0 ? 0 : IOrderbook(orderbook).clearEmptyHead(true);
            }
            // update heads
            askHead = IOrderbook(orderbook).clearEmptyHead(false);
        }
        // set new market price as the orders are matched
        if (lmp != 0) {
            IOrderbook(orderbook).setLmp(lmp);
            emit NewMarketPrice(orderbook, lmp, isBid);
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
            TransferHelper.safeTransfer(isBid ? quote : base, stopTo, remaining);
            if (isMaker) {
                id = _makeOrder(orderbook, remaining, price, isBid, recipient);
                return id;
            }
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
    function _deposit(address base, address quote, uint256 price, uint256 amount, bool isBid, bool isMaker)
        internal
        returns (uint256 withoutFee, address pair)
    {
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }
        // get orderbook address from the base and quote asset
        pair = getPair(base, quote);
        // check infalid pair

        if (pair == address(0)) {
            revert InvalidPair(base, quote, pair);
        }
        // check if the pair is listed
        if (listingDates[pair] > block.timestamp) {
            revert PairNotListedYet(base, quote, listingDates[pair], block.timestamp);
        }

        // check if amount is valid in case of both market and limit
        uint256 converted = _convert(pair, price, amount, !isBid);
        uint256 minRequired = _convert(pair, price, 1, !isBid);

        if (converted <= minRequired) {
            revert OrderSizeTooSmall(converted, minRequired);
        }
        // check sender's fee
        uint256 fee = _fee(base, quote,amount, msg.sender, isMaker);
        withoutFee = amount - fee;
        if (isBid) {
            // transfer input asset give user to this contract
            if (quote != WETH) {
                TransferHelper.safeTransferFrom(quote, msg.sender, address(this), amount);
            } else {
                if (msg.value == 0) {
                    TransferHelper.safeTransferFrom(quote, msg.sender, address(this), amount);
                }
            }
            TransferHelper.safeTransfer(quote, feeTo, fee);
        } else {
            // transfer input asset give user to this contract
            if (base != WETH) {
                TransferHelper.safeTransferFrom(base, msg.sender, address(this), amount);
            } else {
                if (msg.value == 0) {
                    TransferHelper.safeTransferFrom(quote, msg.sender, address(this), amount);
                }
            }
            TransferHelper.safeTransfer(base, feeTo, fee);
        }
        emit OrderDeposit(msg.sender, isBid ? quote : base, fee);

        return (withoutFee, pair);
    }

    /**
     * @dev Deposit amount of asset to the contract with the given asset information and subtracts the fee.
     * @param payment The address of the payment asset.
     * @param sender The address of the sender.
     */
    function _listingDeposit(address payment, address sender) internal returns (string memory terminalName) {
        // check if the sender is admin
        if (hasRole(MARKET_MAKER_ROLE, sender)) {
            return "standard";
        }
        // check if the sender is supported terminal, only terminals can list pairs
        terminalName = IProtocol(incentive).terminalName(sender);
        if (keccak256(bytes(terminalName)) == keccak256(bytes(""))) {
            revert InvalidTerminal(msg.sender);
        }
        uint256 amount = IOrderbookFactory(orderbookFactory).getListingCost(terminalName, payment);
        // check if amount is zero
        if (amount == 0) {
            revert AmountIsZero();
        }
        if (payment != WETH) {
            TransferHelper.safeTransferFrom(payment, msg.sender, address(this), amount);
        }
        TransferHelper.safeTransfer(payment, feeTo, amount);
        return terminalName;
    }

    function _fee(address base, address quote, uint256 amount, address account, bool isMaker) internal view returns (uint256 fee) {
        if (_isContract(incentive) && IProtocol(incentive).isSubscribed(account)) {
            uint32 feeNum = IProtocol(incentive).feeOf(base, quote, account, isMaker);
            return (amount * feeNum) / DENOM;
        }
        return (amount * _baseFee()) / DENOM;
    }

    function _baseFee() internal view returns (uint32) {
        return baseFee;
    }

    function _isContract(address addr) internal view returns (bool isContract) {
        uint256 size;
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
    function _convert(address orderbook, uint256 price, uint256 amount, bool isBid)
        internal
        view
        returns (uint256 converted)
    {
        if (orderbook == address(0)) {
            return 0;
        } else {
            return price == 0
                ? IOrderbook(orderbook).assetValue(amount, isBid)
                : IOrderbook(orderbook).convert(price, amount, isBid);
        }
    }
}
