// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface Ipass {
    function mint(address to_, uint8 metaId_) external returns (uint32);

    function balanceOf(address owner_, uint256 uid_) external view returns (uint256);

    function setRegistered(uint256 id_, bool yesOrNo) external;

    function metaId(uint32 uid_) external view returns (uint8);
}
