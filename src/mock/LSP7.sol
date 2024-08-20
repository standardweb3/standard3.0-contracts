// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.15;

import "@lukso/lsp7-contracts/contracts/LSP7DigitalAsset.sol";

contract MyLSP7Token is LSP7DigitalAsset {
    constructor(
        string memory name, // Name of the token
        string memory symbol, // Symbol of the token
        address tokenOwner, // Owner able to add extensions and change metadata
        uint256 lsp4tokenType, // 0 if representing a fungible token, 1 if representing an NFT
        bool isNonDivisible // false for decimals equal to 18, true for decimals equal to 0
    ) LSP7DigitalAsset(name, symbol, tokenOwner, lsp4tokenType, isNonDivisible) {
        // _mint(to, amount, force, data)
        // force: should be set to true to allow EOA to receive tokens
        // data: only relevant if the `to` is a smart contract supporting LSP1.
        _mint(tokenOwner, 200000, true, "");
    }
}