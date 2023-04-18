// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

interface IOrderbookFactory {
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
}
