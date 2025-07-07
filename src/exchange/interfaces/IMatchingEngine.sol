// SPDX-License-Identifier: BUSL-1.1
import {ExchangeOrderbook} from "../libraries/ExchangeOrderbook.sol";

pragma solidity ^0.8.24;

interface IMatchingEngine {
    struct OrderMatch {
        address owner;
        uint256 baseFee;
        uint256 quoteFee;
    }

    struct OrderResult {
        uint256 makePrice;
        uint256 placed;
        uint32 id;
    }

    struct CancelOrderInput {
        address base;
        address quote;
        bool isBid;
        uint32 orderId;
    }

    struct CreateOrderInput {
        address base;
        address quote;
        bool isBid;
        bool isLimit;
        uint32 orderId;
        uint256 price;
        uint256 amount;
        uint32 n;
        address recipient;
    }

    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success);

    function setDefaultFee(bool isMaker, uint32 fee_) external returns (bool success);

    function setDefaultSpread(uint32 buy, uint32 sell, bool isMkt) external returns (bool success);

    function setSpread(address base, address quote, uint32 buy, uint32 sell, bool isMkt)
        external
        returns (bool success);

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
    ) external returns (OrderResult memory result);

    function updatePair(address base, address quote, uint256 listingPrice, uint256 listingDate)
        external
        returns (address pair);

    // user functions
    function marketBuy(
        address base,
        address quote,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external returns (OrderResult memory result);

    function marketSell(
        address base,
        address quote,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external returns (OrderResult memory result);

    function marketBuyETH(address base, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (OrderResult memory result);

    function marketSellETH(address quote, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (OrderResult memory result);

    function limitBuy(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        address recipient
    ) external returns (OrderResult memory result);

    function limitSell(
        address base,
        address quote,
        uint256 price,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        address recipient
    ) external returns (OrderResult memory result);

    function limitBuyETH(address base, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (OrderResult memory result);

    function limitSellETH(address quote, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (OrderResult memory result);

    function addPair(address base, address quote, uint256 listingPrice, uint256 listingDate, address payment)
        external
        returns (address pair);

    function addPairETH(address base, address quote, uint256 listingPrice, uint256 listingDate)
        external
        payable
        returns (address book);

    function createOrder(CreateOrderInput memory createOrderData) external payable returns (OrderResult memory result);

    function createOrders(
        CreateOrderInput[] memory createOrderData
    ) external returns (OrderResult[] memory results);

    function updateOrders(CreateOrderInput[] memory createOrderData)
        external
        returns (OrderResult[] memory results);

    function cancelOrder(address base, address quote, bool isBid, uint32 orderId) external returns (uint256 refunded);

    function cancelOrders(CancelOrderInput[] memory cancelOrders) external returns (uint256[] memory refunded);

    function getOrder(address base, address quote, bool isBid, uint32 orderId)
        external
        view
        returns (ExchangeOrderbook.Order memory);

    function getPair(address base, address quote) external view returns (address book);

    function heads(address base, address quote) external view returns (uint256 bidHead, uint256 askHead);

    function mktPrice(address base, address quote) external view returns (uint256);

    function convert(address base, address quote, uint256 amount, bool isBid)
        external
        view
        returns (uint256 converted);

    function feeTo() external view returns (address);

    function incentive() external view returns (address);

    function feeOf(address base, address quote, address account, bool isMaker) external view returns (uint32 feeNum);
}
