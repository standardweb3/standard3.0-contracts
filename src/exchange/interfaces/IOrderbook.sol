// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "../libraries/ExchangeOrderbook.sol";

interface IOrderbook {
    function initialize(uint256 id_, address base_, address quote_, address engine_) external;

    function setLmp(uint256 price) external;

    function placeAsk(address owner, uint256 price, uint256 amount) external returns (uint32 id, bool foundDmt);

    function placeBid(address owner, uint256 price, uint256 amount) external returns (uint32 id, bool foundDmt);

    function removeDmt(bool isBid) external returns (ExchangeOrderbook.Order memory order);

    function cancelOrder(bool isBid, uint32 orderId, address owner) external returns (uint256 remaining);

    function execute(uint32 orderId, bool isBid, address sender, uint256 amount, bool clear)
        external
        returns (address owner);

    function clearEmptyHead(bool isBid) external returns (uint256 head);

    function fpop(bool isBid, uint256 price, uint256 remaining)
        external
        returns (uint32 orderId, uint256 required, bool clear);

    function getRequired(bool isBid, uint256 price, uint32 orderId) external view returns (uint256 required);

    function lmp() external view returns (uint256);

    function heads() external view returns (uint256, uint256);

    function askHead() external view returns (uint256);

    function bidHead() external view returns (uint256);

    function orderHead(bool isBid, uint256 price) external view returns (uint32);

    function mktPrice() external view returns (uint256);

    function getPrices(bool isBid, uint32 n) external view returns (uint256[] memory);

    function nextPrice(bool isBid, uint256 price) external view returns (uint256 next);

    function nextOrder(bool isBid, uint256 price, uint32 orderId) external view returns (uint32 next);

    function sfpop(bool isBid, uint256 price, uint32 orderId, bool isHead)
        external
        view
        returns (uint32 id, uint256 required, bool clear);

    function getPricesPaginated(bool isBid, uint32 start, uint32 end) external view returns (uint256[] memory);

    function getOrderIds(bool isBid, uint256 price, uint32 n) external view returns (uint32[] memory);

    function getOrders(bool isBid, uint256 price, uint32 n) external view returns (ExchangeOrderbook.Order[] memory);

    function getOrdersPaginated(bool isBid, uint256 price, uint32 start, uint32 end)
        external
        view
        returns (ExchangeOrderbook.Order[] memory);

    function getOrder(bool isBid, uint32 orderId) external view returns (ExchangeOrderbook.Order memory);

    function getBaseQuote() external view returns (address base, address quote);

    function assetValue(uint256 amount, bool isBid) external view returns (uint256 converted);

    function isEmpty(bool isBid, uint256 price) external view returns (bool);

    function convertMarket(uint256 amount, bool isBid) external view returns (uint256 converted);

    function convert(uint256 price, uint256 amount, bool isBid) external view returns (uint256 converted);
}
