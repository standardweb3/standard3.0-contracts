// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IMetadata {
    function meta(uint256 _id) external view returns (string memory);
}
