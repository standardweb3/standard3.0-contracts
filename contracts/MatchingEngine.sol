// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IOrderbookFactory.sol";
import "./interfaces/IOrderbook.sol";
import "./interfaces/IOrder.sol";

// Onchain Matching engine for the orders
contract MatchingEngine is AccessControl {
    // fee recipient
    address private feeTo;
    // fee denominator
    uint256 public feeDenom;
    // fee numerator
    uint256 public feeNum;
    // Address of the orderbooks
    address[] public orderbooks;

    // Factories
    address public orderbookFactory;
    address public orderFactory;

    /// Hashmap-style linked list of prices to route orders
    // key: price, value: next_price (next_price > price)
    mapping(uint256 => uint256) public bidPrices;
    // key: price, value: next_price (next_price < price)
    mapping(uint256 => uint256) public askPrices;

    // Head of the bid price linked list(i.e. highest bid price)
    uint256 public bidHead;
    // Head of the ask price linked list(i.e. lowest ask price)
    uint256 public askHead;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeTo = msg.sender;
        feeDenom = 1000;
        feeNum = 3;
    }

    function initialize(
        address orderbookFactory_,
        address orderFactory_
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        orderbookFactory = orderbookFactory_;
        orderFactory = orderFactory_;
    }

    function mktPrice() external view returns (uint256) {
        return (bidHead + askHead) / 2;
    }

    function setFee(uint256 feeNum_, uint256 feeDenom_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        feeNum = feeNum_;
        feeDenom = feeDenom_;
    }

    function setFeeTo(address feeTo_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeTo = feeTo_;
    }

    function _next(bool isAsk, uint256 price) internal view returns (uint256) {
        if (isAsk) {
            return askPrices[price];
        } else {
            return bidPrices[price];
        }
    }

    // for askPrices, lower ones are next, for bidPrices, higher ones are next
    function _insert(bool isAsk, uint256 price) internal {
        // insert ask price to the linked list
        if (isAsk) {
            uint256 last = askHead;
            // Traverse through list until we find the right spot
            while (price < last) {
                last = askPrices[last];
            }
            // what if price is the lowest?
            if (last > price) {
                askPrices[price] = last;
                askHead = price;
            }
            // what if price is in the middle of the list?
            else if (askPrices[last] < price) {
                askPrices[price] = askPrices[last];
                askPrices[last] = price;
            }
            // what if price is the highest?
            else {
                askPrices[last] = price;
            }
        }
        // insert bid price to the linked list
        else {
            uint256 last = askHead;
            // Traverse through list until we find the right spot
            while (price > last) {
                last = bidPrices[last];
            }
            // what if price is the highest?
            if (last < price) {
                bidPrices[price] = last;
                askHead = price;
            }
            // what if price is in the middle of the list?
            else if (bidPrices[last] > price) {
                bidPrices[price] = askPrices[last];
                askPrices[last] = price;
            }
            // what if price is the lowest?
            else {
                bidPrices[last] = price;
            }
        }
    }

    function _execute(
        address order,
        address from,
        uint256 amount,
        uint256 priceAt,
        bool isAsk
    ) internal {
        uint256 required = isAsk ? amount / priceAt : amount * priceAt;
        if (isAsk) {
            require(
                IOrder(order).verifyRatio(
                    IOrder(order).deposit(),
                    from,
                    amount,
                    required
                ),
                "Invalid ratio"
            );
            IERC20(from).transfer(order, required);
        } else {
            require(
                IOrder(order).verifyRatio(
                    from,
                    IOrder(order).deposit(),
                    required,
                    amount
                ),
                "Invalid ratio"
            );
            IERC20(from).transfer(order, required);
        }
        // let the order escrow the order
        IOrder(order).execute(msg.sender, amount);
    }

    // match bid if isAsk == true, match ask if isAsk == false
    function _matchAt(
        address orderbook,
        address from,
        bool isAsk,
        uint256 amount,
        uint256 priceAt
    ) internal returns (uint256 remaining) {
        remaining = amount;
        while (
            remaining == 0 || IOrderbook(orderbook).isEmpty(priceAt, !isAsk)
        ) {
            // Dequeue OrderQueue by price, if ask you get bid order, if bid you get ask order
            uint256 orderId = IOrderbook(orderbook).dequeue(priceAt, !isAsk);
            address order = IOrderbook(orderbook).getOrder(orderId);
            if (remaining < IOrder(order).depositAmount()) {
                _execute(order, from, remaining, priceAt, isAsk);
                // emit event orderfilled, no need to edit price head
                return 0;
            } else {
                remaining -= IOrder(order).depositAmount();
                _execute(order, from, IOrder(order).depositAmount(), priceAt, isAsk);
                // event orderfullfilled
            }
        }
        // update price head
        // the request was ask
        if (isAsk) {
            bidHead = _next(!isAsk, priceAt);
        }
        // the request was bid
        else {
            askHead = _next(isAsk, priceAt);
        }
        return remaining;
    }

    // match bid if isAsk == true, match ask if isAsk == false
    function _marketOrder(
        address orderbook,
        uint256 amount,
        address base,
        address quote,
        address from,
        bool isAsk
    ) internal {
        uint256 remaining = amount;
        if (isAsk) {
            require(quote == from, "Order is not ask");
            // check if there is any ask order in the price at the head
            while (remaining > 0 && askHead != 0) {
                remaining = _matchAt(
                    orderbook,
                    from,
                    true,
                    remaining,
                    askHead
                );
            }
        } else {
            require(base == from, "Order is not bid");
            // check if there is any bid order in the price at the head
            while (remaining > 0 && bidHead != 0) {
                remaining = _matchAt(
                    orderbook,
                    from,
                    false,
                    remaining,
                    bidHead
                );
            }
        }
    }

    function _limitOrder(
        address orderbook,
        uint256 amount,
        address base,
        address quote,
        address from,
        bool isAsk,
        uint256 limitPrice
    ) internal returns (uint256 remaining) {
        remaining = amount;
        if (isAsk) {
            require(quote == from, "Order is not ask");
            // check if there is any ask order in the price at the head
            while (remaining > 0 && askHead < limitPrice) {
                remaining = _matchAt(
                    orderbook,
                    from,
                    true,
                    remaining,
                    askHead
                );
            }
        } else {
            require(base == from, "Order is not ask");
            // check if there is any bid order in the price at the head
            while (remaining > 0 && bidHead > limitPrice) {
                remaining = _matchAt(
                    orderbook,
                    from,
                    false,
                    remaining,
                    bidHead
                );
            }
        }
        return remaining;
    }

    // Market orders
    function marketBuy(
        address token,
        address from,
        uint256 amount
    ) external {
        address orderbook = IOrderbookFactory(orderbookFactory).getBookByPair(
            token,
            from
        );
        (address base, address quote) = IOrderbookFactory(orderbook)
            .getBaseQuote(orderbook);
        // transfer input asset from user to this contract
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        // send fee to fee receiver
        uint fee = amount * feeNum/ feeDenom;
        IERC20(from).transfer(feeTo, fee);
        // negate on from if the asset is not the base
        _marketOrder(orderbook, amount-fee, base, quote, from, token == base);
    }

    function marketSell(
        address token,
        address from,
        uint256 amount
    ) external {
        address orderbook = IOrderbookFactory(orderbookFactory).getBookByPair(
            token,
            from
        );
        (address base, address quote) = IOrderbookFactory(orderbook)
            .getBaseQuote(orderbook);
        // send fee to fee receiver
        uint fee = amount * feeNum/ feeDenom;
        IERC20(from).transfer(feeTo, fee);
        // negate on from if the asset is not the quote
        _marketOrder(orderbook, amount-fee, base, quote, from, token != base);
    }

    // Limit orders
    function limitBuy(
        address token,
        address from,
        uint256 amount,
        uint256 at
    ) external {
        // place order with remaining
        address orderbook = IOrderbookFactory(orderbookFactory).getBookByPair(
            token,
            from
        );
        (address base, address quote) = IOrderbookFactory(orderbook)
            .getBaseQuote(orderbook);
        // send fee to fee receiver
        uint fee = amount * feeNum/ feeDenom;
        IERC20(from).transfer(feeTo, fee);
        // negate on from if the asset is not the base
        uint256 remaining = _limitOrder(
            orderbook,
            amount,
            base,
            quote,
            from,
            token == base,
            at
        );
        if (remaining > 0) {
            // create order
            IOrderbook(orderbook).placeAsk(at, remaining);
            // insert ask price to the linked list
            _insert(true, at);
        }
    }

    function limitSell(
        address token,
        address from,
        uint256 amount,
        uint256 at
    ) external {
        // place order with remaining
        address orderbook = IOrderbookFactory(orderbookFactory).getBookByPair(
            token,
            from
        );
        (address base, address quote) = IOrderbookFactory(orderbook)
            .getBaseQuote(orderbook);
        // send fee to fee receiver
        uint fee = amount * feeNum/ feeDenom;
        IERC20(from).transfer(feeTo, fee);
        // negate on from if the asset is not the quote
        uint256 remaining = _limitOrder(
            orderbook,
            amount,
            base,
            quote,
            from,
            token != base,
            at
        );
        if (remaining > 0) {
            // create order
            IOrderbook(orderbook).placeBid(at, remaining);
            // insert bid price to the linked list
            _insert(false, at);
        }
    }

    function addBook(address base, address quote)
        external
        returns (address book)
    {
        // TODO: take fee from the sender (e.g. 100k value of network token)

        // create pair name (i.e. ETH/DAI, <Bid/Ask>, <Base/Quote>)
        // get pair names from erc20
        string memory baseSymbol = IERC20(base).symbol();
        string memory quoteSymbol = IERC20(quote).symbol();
        string memory pairName = string(
            abi.encodePacked(baseSymbol, "/", quoteSymbol)
        );
        // create orderbook for the pair
        (address orderBook, uint256 id) = IOrderbookFactory(orderbookFactory)
            .createBook(pairName, base, quote, orderFactory, address(this));
        // add orderbook to the list of orderbooks
        orderbooks.push(orderBook);

        return orderBook;
    }

    function getOrderbook(uint256 id) external view returns (address) {
        return orderbooks[id];
    }
}
