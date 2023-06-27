// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IAccountant {

    function isSubscribed(uint32 uid_) external view returns (bool);

    function decimals() external view returns (uint8);

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256);

    function subtractMP(
        address account,
        uint256 nthEra,
        uint256 amount
    ) external;

    function pointOf(
        address account,
        uint256 nthEra
    ) external view returns (uint256);
}