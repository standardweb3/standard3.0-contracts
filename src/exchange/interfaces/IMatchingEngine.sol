// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

interface IMatchingEngine {
    // admin functions
    function setFeeTo(address feeTo_) external returns (bool success);

    function setDefaultSpread(uint32 buy, uint32 sell) external returns (bool success);

    function setSpread(address base, address quote, uint32 buy, uint32 sell) external returns (bool success);

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

    function marketBuyETH(address base, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id);

    function marketSellETH(address quote, bool isMaker, uint32 n, address recipient, uint32 slippageLimit)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id);

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

    function limitBuyETH(address base, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id);

    function limitSellETH(address quote, uint256 price, bool isMaker, uint32 n, address recipient)
        external
        payable
        returns (uint256 makePrice, uint256 placed, uint32 id);

    function addPair(address base, address quote, uint256 listingPrice, uint256 listingDate, address payment)
        external
        returns (address pair);

    function addPairETH(address base, address quote, uint256 listingPrice, uint256 listingDate)
        external
        returns (address pair);

    function cancelOrder(address base, address quote, bool isBid, uint32 orderId) external returns (uint256 refunded);

    function cancelOrders(address[] memory base, address[] memory quote, bool[] memory isBid, uint32[] memory orderIds)
        external
        returns (uint256[] memory refunded);

    function getOrderbookById(uint256 id) external view returns (address);

    function getBaseQuote(address orderbook) external view returns (address base, address quote);

    function getPairs(uint256 start, uint256 end) external view returns (address[] memory pairs);

    function getPairsWithIds(uint256[] memory ids) external view returns (address[] memory pairs);

    function getPairNames(uint256 start, uint256 end) external view returns (string[] memory names);

    function getPairNamesWithIds(uint256[] memory ids) external view returns (string[] memory names);

    function getMktPrices(uint256 start, uint256 end) external view returns (uint256[] memory mktPrices);

    function getMktPricesWithIds(uint256[] memory ids) external view returns (uint256[] memory mktPrices);

    function getPrices(address base, address quote, bool isBid, uint32 n) external view returns (uint256[] memory);

    function getPricesPaginated(address base, address quote, bool isBid, uint32 start, uint32 end)
        external
        view
        returns (uint256[] memory);

    function getOrders(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (address[] memory);

    function getOrdersPaginated(address base, address quote, bool isBid, uint256 price, uint32 start, uint32 end)
        external
        view
        returns (address[] memory);

    function getOrder(address base, address quote, bool isBid, uint32 orderId) external view returns (address);

    function getOrderIds(address base, address quote, bool isBid, uint256 price, uint32 n)
        external
        view
        returns (uint32[] memory);

    function getPair(address base, address quote) external view returns (address book);

    function heads(address base, address quote) external view returns (uint256 bidHead, uint256 askHead);

    function mktPrice(address base, address quote) external view returns (uint256);

    function convert(address base, address quote, uint256 amount, bool isBid)
        external
        view
        returns (uint256 converted);
}
