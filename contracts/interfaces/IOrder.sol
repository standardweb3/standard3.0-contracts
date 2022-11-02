// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.10;

interface IOrder {
    function execute(address sender, uint256 amount) external;

    function deposit() external view returns (address deposit);

    function depositAmount() external view returns (uint256 depositAmount);

    function initialize(
        uint256 pairId_,
        address owner_,
        address orderbook_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) external;

    function verifyRatio(address base, address quote, uint256 baseAmount, uint256 quoteAmount) external view returns (bool success);
}
