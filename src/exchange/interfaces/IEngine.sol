// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

interface IEngine {
    function mktPrice(
        address base,
        address quote
    ) external view returns (uint256 mktPrice);

    function getOrderbook(uint256 bookId) external view returns (address);

    function marketBuy(
        address base,
        address quote,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external;

    function marketSell(
        address base,
        address quote,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external;

    function marketBuyETH(
        address base,
        bool isMaker,
        uint32 n,
        uint32 uid
    ) external payable returns (bool);

    function marketSellETH(
        address quote,
        bool isMaker,
        uint32 n,
        uint32 uid
    ) external payable returns (bool);

    function limitBuy(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external;

    function limitBuyETH(
        address base,
        uint256 price,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable;


    function limitSell(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external;

    function limitSellETH(
        address quote,
        uint256 price,
        bool isMaker,
        uint32 n,
        uint32 uid,
        address recipient
    ) external payable;

    function getPair(
        address base,
        address quote
    ) external view returns (address book);
}
