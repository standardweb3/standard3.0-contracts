// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface IEngine {
    function mktPrice(
        address base,
        address quote
    ) external view returns (uint256 mktPrice);

    function getOrderbook(uint256 bookId) external view returns (address);

    function marketBuy(address base, address quote, uint256 amount) external;

    function marketSell(address base, address quote, uint256 amount) external;

    function marketBuyEth(address quote, uint256 amount) external;

    function marketSellEth(address quote, uint256 amount) external;

    function limitBuy(
        address base,
        address quote,
        uint256 price,
        uint256 quoteAmount,
        bool isMaker,
        uint32 n,
        uint32 uid
    ) external;

    function limitSell(
        address base,
        address quote,
        uint256 price,
        uint256 baseAmount,
        bool isMaker,
        uint32 n,
        uint32 uid
    ) external;

    function addPair(
        address base,
        address quote
    ) external returns (address book);
}
