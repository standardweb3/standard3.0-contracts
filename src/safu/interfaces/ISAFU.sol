// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.0;

interface ISAFU {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}
