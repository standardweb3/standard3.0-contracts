// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IOrderFactory {
    function createOrder(
        uint256 pairId_,
        address owner_,
        address orderbook_,
        address WETH_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) external returns (address order, uint256 orderId);

    function getOrder(uint256 orderId_) external view returns (address);

    /// Address of wrapped eth
    function WETH() external view returns (address);
}
