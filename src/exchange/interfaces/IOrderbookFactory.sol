// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IOrderbookFactory {
    struct Pair {
        address base;
        address quote;
    }

    function engine() external view returns (address);

    function impl() external view returns (address);

    function createBook(address base_, address quote_) external returns (address pair);

    function setListingCost(string memory terminal, address payment, uint256 amount) external returns (uint256);

    function isClone(address vault) external view returns (bool cloned);

    function getPair(address base, address quote) external view returns (address book);

    function getPairs(uint256 start, uint256 end) external view returns (Pair[] memory);

    function getPairsWithIds(uint256[] memory ids) external view returns (Pair[] memory pairs);

    function getPairNames(uint256 start, uint256 end) external view returns (string[] memory names);

    function getPairNamesWithIds(uint256[] memory ids) external view returns (string[] memory names);

    function getBaseQuote(address pair) external view returns (address base, address quote);

    function getByteCode() external view returns (bytes memory bytecode);

    function getListingCost(string memory terminal, address payment) external view returns (uint256 amount);
}
