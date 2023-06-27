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
        uint256 amount,
        uint256 price
    ) external;

    function limitSell(
        address base,
        address quote,
        uint256 amount,
        uint256 price
    ) external;

    function addPair(
        address base,
        address quote
    ) external returns (address book);
}
