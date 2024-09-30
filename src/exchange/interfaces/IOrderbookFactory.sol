// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IOrderbookFactory {
    struct Pair {
        address base;
        address quote;
    }

    function engine() external view returns (address);

    function createBook(
        address base_,
        address quote_
    ) external returns (address orderbook);

    function isClone(address vault) external view returns (bool cloned);

    function getBook(uint256 bookId_) external view returns (address);

    function getPair(address base, address quote) external view returns (address book);

    function getPairs(uint256 start, uint256 end) external view returns (Pair[] memory);

    function getPairsWithIds(uint256[] memory ids) external view returns (Pair[] memory pairs);

    function getPairNames(uint256 start, uint256 end) external view returns (string[] memory names);

    function getPairNamesWithIds(uint256[] memory ids) external view returns (string[] memory names);

    function getBaseQuote(address orderbook) external view returns (address base, address quote);
}
