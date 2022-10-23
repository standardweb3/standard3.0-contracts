// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IEngine {
    function mktPrice(address base, address quote) external view returns (uint256 mktPrice);
    function getOrderbook(uint256 bookId) external view returns (address);
    function marketBuy(
        address token,
        address from,
        uint256 amount
    ) external;
    function marketSell(
        address token,
        address from,
        uint256 amount
    ) external;
    function marketBuyEth(
        address from,
        uint256 amount
    ) external;
    function marketSellEth(
        address from,
        uint256 amount
    ) external;
    function limitBuy(
        address token,
        address from,
        uint256 amount,
        uint256 price
    ) external;
    function limitSell(
        address token,
        address from,
        uint256 amount,
        uint256 price
    ) external;
    function addBook(
        address base,
        address quote
    ) external returns (address book);
}
