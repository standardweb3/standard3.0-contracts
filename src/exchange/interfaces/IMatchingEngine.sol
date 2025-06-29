// SPDX-License-Identifier: BUSL-1.1
import {ExchangeOrderbook} from "./IOrderbook.sol";

pragma solidity ^0.8.24;

interface IMatchingEngine {
    struct CancelOrder {
        address base;
        address quote;
        bool isBid;
        uint32 orderId;
    }

    struct UpdateOrder {
        address base;
        address quote;
        bool isBid;
        uint32 orderId;
        uint256 price;
        uint256 amount;
        uint32 n;
        address recipient;
    }

    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success);

    function setDefaultSpread(
        uint32 buy,
        uint32 sell,
        bool isMkt
    ) external returns (bool success);

    function setSpread(
        address base,
        address quote,
        uint32 buy,
        uint32 sell,
        bool isMkt
    ) external returns (bool success);

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
    ) external returns (uint256 makePrice, uint256 placed, uint32 id);

    function updatePair(
        address base,
        address quote,
        uint256 listingPrice,
        uint256 listingDate
    ) external returns (address pair);

    // user functions
    function marketBuy(
        address base,
        address quote,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external returns (uint256 makePrice, uint256 placed, uint32 id);

    function marketSell(
        address base,
        address quote,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external returns (uint256 makePrice, uint256 placed, uint32 id);

    function marketBuyETH(
        address base,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id);

    function marketSellETH(
        address quote,
        bool isMaker,
        uint32 n,
        address recipient,
        uint32 slippageLimit
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id);

    function limitBuy(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        address recipient
    ) external returns (uint256 makePrice, uint256 placed, uint32 id);

    function limitSell(
        address base,
        address quote,
        uint256 price,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        address recipient
    ) external returns (uint256 makePrice, uint256 placed, uint32 id);

    function limitBuyETH(
        address base,
        uint256 price,
        bool isMaker,
        uint32 n,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id);

    function limitSellETH(
        address quote,
        uint256 price,
        bool isMaker,
        uint32 n,
        address recipient
    ) external payable returns (uint256 makePrice, uint256 placed, uint32 id);

    function addPair(
        address base,
        address quote,
        uint256 listingPrice,
        uint256 listingDate,
        address payment
    ) external returns (address pair);

   function addPairETH(
        address base,
        address quote,
        uint256 listingPrice,
        uint256 listingDate
    ) external payable returns (address book);

    function cancelOrder(
        address base,
        address quote,
        bool isBid,
        uint32 orderId
    ) external returns (uint256 refunded);

    function cancelOrders(
        CancelOrder[] memory cancelOrders
    ) external returns (uint256[] memory refunded);

    function getOrder(
        address base,
        address quote,
        bool isBid,
        uint32 orderId
    ) external view returns (ExchangeOrderbook.Order memory);

    function getPair(
        address base,
        address quote
    ) external view returns (address book);

    function heads(
        address base,
        address quote
    ) external view returns (uint256 bidHead, uint256 askHead);

    function mktPrice(
        address base,
        address quote
    ) external view returns (uint256);

    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted);
}
