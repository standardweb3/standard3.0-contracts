// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.5.0;

interface IERC20Minimal {
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function mint(address to, uint256 amount) external;
}
