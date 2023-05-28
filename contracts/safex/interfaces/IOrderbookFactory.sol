// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

interface IOrderbookFactory {
    struct Pair {
        address base;
        address quote;
    }

    function createBook(
        address bid_,
        address ask_,
        address engine_
    ) external returns (address orderbook);

    function getBook(uint256 bookId_) external view returns (address orderbook);

    function getBookByPair(
        address base,
        address quote
    ) external view returns (address book);

    function getBaseQuote(
        address orderbook
    ) external view returns (address base, address quote);

    /// Address of a manager
    function engine() external view returns (address);

    function getPairs(uint start, uint end) external view returns (Pair[] memory);
}