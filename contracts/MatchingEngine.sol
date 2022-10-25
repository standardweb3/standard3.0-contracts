// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOrderbookFactory.sol";
import "./interfaces/IOrderbook.sol";
import "./libraries/TransferHelper.sol";

// Onchain Matching engine for the orders
contract MatchingEngine is AccessControl {
    // fee recipient
    address private feeTo;
    // fee denominator
    uint256 public feeDenom;
    // fee numerator
    uint256 public feeNum;
    // Factories
    address public orderbookFactory;

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        feeTo = msg.sender;
        feeDenom = 1000;
        feeNum = 3;
    }

    function initialize(address orderbookFactory_)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        orderbookFactory = orderbookFactory_;
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

    // match bid if isAsk == true, match ask if isAsk == false
    function _matchAt(
        address orderbook,
        address give,
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
            uint256 depositAmount = IOrderbook(orderbook).getOrderDepositAmount(
                orderId
            );
            if (remaining < depositAmount) {
                TransferHelper.safeTransfer(give, orderbook, remaining);
                IOrderbook(orderbook).execute(orderId, msg.sender, remaining);
                // emit event orderfilled, no need to edit price head
                return 0;
            } else {
                remaining -= depositAmount;
                TransferHelper.safeTransfer(give, orderbook, depositAmount);
                IOrderbook(orderbook).execute(
                    orderId,
                    msg.sender,
                    depositAmount
                );
                // event orderfullfilled
            }
        }
        return remaining;
    }

    function _limitOrder(
        address orderbook,
        uint256 amount,
        address give,
        bool isAsk,
        uint256 limitPrice
    ) internal returns (uint256 remaining) {
        remaining = amount;
        (uint256 askHead, uint256 bidHead) = IOrderbook(orderbook).heads();
        if (isAsk) {
            // check if there is any ask order in the price at the head
            while (remaining > 0 && askHead != 0 && askHead < limitPrice) {
                remaining = _matchAt(orderbook, give, true, remaining, askHead);
            }
        } else {
            // check if there is any bid order in the price at the head
            while (remaining > 0 && bidHead != 0 && bidHead > limitPrice) {
                remaining = _matchAt(
                    orderbook,
                    give,
                    false,
                    remaining,
                    bidHead
                );
            }
        }
        return (remaining);
    }

    function _deposit(
        address base,
        address quote,
        uint256 amount,
        bool isAsk
    ) internal returns (uint256 withoutFee, address orderbook) {
        orderbook = IOrderbookFactory(orderbookFactory).getBookByPair(
            base,
            quote
        );
        uint256 fee = (amount * feeNum) / feeDenom;
        withoutFee = amount - fee;
        if (isAsk) {
            // transfer input asset give user to this contract
            TransferHelper.safeTransferFrom(
                quote,
                msg.sender,
                address(this),
                amount
            );
            // send fee to fee receiver
            TransferHelper.safeTransfer(quote, feeTo, fee);
        } else {
            // transfer input asset give user to this contract
            TransferHelper.safeTransferFrom(
                base,
                msg.sender,
                address(this),
                amount
            );
            // send fee to fee receiver
            TransferHelper.safeTransfer(base, feeTo, fee);
        }

        return (withoutFee, orderbook);
    }

    // Market orders
    function marketBuy(
        address base,
        address quote,
        uint256 amount,
        bool isStop
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            true
        );
        // negate on give if the asset is not the base
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            quote,
            true,
            type(uint256).max
        );
        // add stop order on market price
        if (isStop) {
            uint256 mktPrice = IOrderbook(orderbook).mktPrice();
            _stopOrder(orderbook, remaining, mktPrice, true);
        }
        // Take profit
        else {
            TransferHelper.safeTransfer(quote, msg.sender, remaining);
        }
    }

    function marketSell(
        address base,
        address quote,
        uint256 amount,
        bool isStop
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false
        );
        // negate on give if the asset is not the base
        uint256 remaining = _limitOrder(
            orderbook,
            withoutFee,
            quote,
            true,
            type(uint256).max
        );

        // add stop order on market price
        if (isStop) {
            uint256 mktPrice = IOrderbook(orderbook).mktPrice();
            _stopOrder(orderbook, remaining, mktPrice, true);
        }
        // Take profit
        else {
            TransferHelper.safeTransfer(base, msg.sender, remaining);
        }
    }

    // Limit orders
    function limitBuy(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        bool isStop
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            true
        );
        // negate on give if the asset is not the base
        uint256 remaining = _limitOrder(orderbook, withoutFee, quote, true, at);
        if (remaining > 0) {
            if (isStop) {
                _stopOrder(orderbook, remaining, at, true);
            } else {
                // take profit
                TransferHelper.safeTransfer(quote, msg.sender, remaining);
            }
        }
    }

    function limitSell(
        address base,
        address quote,
        uint256 amount,
        uint256 at,
        bool isStop
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false
        );
        // negate on give if the asset is not the quote
        uint256 remaining = _limitOrder(orderbook, withoutFee, base, false, at);
        if (remaining > 0) {
            if (isStop) {
                _stopOrder(orderbook, remaining, at, false);
            } else {
                // take profit
                TransferHelper.safeTransfer(base, msg.sender, remaining);
            }
        }
    }

    function _stopOrder(
        address orderbook,
        uint256 withoutFee,
        uint256 at,
        bool isAsk
    ) internal {
        // create order
        if (isAsk) {
            IOrderbook(orderbook).placeAsk(msg.sender, at, withoutFee);
        } else {
            IOrderbook(orderbook).placeBid(msg.sender, at, withoutFee);
        }
    }

    // Stop orders
    function stopBuy(
        address base,
        address quote,
        uint256 amount,
        uint256 at
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false
        );
        _stopOrder(orderbook, withoutFee, at, true);
    }

    function stopSell(
        address base,
        address quote,
        uint256 amount,
        uint256 at
    ) external {
        (uint256 withoutFee, address orderbook) = _deposit(
            base,
            quote,
            amount,
            false
        );
        _stopOrder(orderbook, withoutFee, at, false);
    }

    function addBook(address base, address quote)
        external
        returns (address book)
    {
        // TODO: take fee give the sender (e.g. 100k value of network take)

        // create orderbook for the pair
        address orderBook = IOrderbookFactory(orderbookFactory).createBook(
            base,
            quote,
            address(this)
        );

        return orderBook;
    }

    function getOrderbook(uint256 id) external view returns (address) {
        return IOrderbookFactory(orderbookFactory).getBook(id);
    }

    function getOrderbookBaseQuote(address orderbook)
        external
        view
        returns (address, address)
    {
        return IOrderbookFactory(orderbookFactory).getBaseQuote(orderbook);
    }
}
