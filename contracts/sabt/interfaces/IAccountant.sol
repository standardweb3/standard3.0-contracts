// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IAccountant {
    function convert(
        address base,
        address quote,
        uint256 amount,
        bool isBid
    ) external view returns (uint256 converted);

    function isSubscribed(uint32 uid_) external view returns (bool);

    function decimals() external view returns (uint8);

    function balanceOf(
        address owner,
        uint256 id
    ) external view returns (uint256);

    function subtractTP(
        address account,
        uint256 nthEra,
        uint256 amount
    ) external;

    function getSubSTND(uint32 uid_) external view returns (uint64 sub);

    function getMeta(uint32 uid_) external view returns (uint8 meta);
}