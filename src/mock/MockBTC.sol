// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.24;

import "@openzeppelin/src/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockBTC is ERC20PresetMinterPauser {
    constructor(string memory name, string memory symbol) ERC20PresetMinterPauser(name, symbol) {}

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
