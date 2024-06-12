// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "./ERC20MintablePausableBurnable.sol";

contract MockBTC is ERC20MintablePausableBurnable {
    constructor(string memory name, string memory symbol) ERC20MintablePausableBurnable(name, symbol) {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
