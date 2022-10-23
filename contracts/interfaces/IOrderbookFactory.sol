// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IOrderbookFactory {
    function createBook(
        string memory pairName_,
        address bid_,
        address ask_,
        address orderFactory_,
        address engine_
    ) external returns (address orderbook, uint256 bookId);

    function getBook(uint256 bookId_) external view returns (address);

    function getBookByPair(address base, address quote) external view  returns (address book); 

    function getBaseQuote(address orderbook) external view returns (address base, address quote);

    /// Address of wrapped eth
    function WETH() external view returns (address);

    /// Address of a manager
    function engine() external view returns (address);
}
