// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.10;

library NewOrderLibrary {
    // Order struct
    struct Order {
        address owner;
        bool isAsk;
        uint256 price;
        address deposit;
        uint256 depositAmount;
        uint256 filled;
    }

    function _createOrder(
        address owner_,
        bool isAsk_,
        uint256 price_,
        address deposit_,
        uint256 depositAmount_
    ) internal pure returns (Order memory order) {
        Order memory ord = Order({
            owner: owner_,
            isAsk: isAsk_,
            price: price_,
            deposit: deposit_,
            depositAmount: depositAmount_,
            filled: 0
        });
        return ord;
    }
}