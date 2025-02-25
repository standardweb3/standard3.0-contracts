// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "./ERC20MintablePausableBurnable.sol";

contract MockToken is ERC20MintablePausableBurnable {
    uint8 _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20MintablePausableBurnable(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
